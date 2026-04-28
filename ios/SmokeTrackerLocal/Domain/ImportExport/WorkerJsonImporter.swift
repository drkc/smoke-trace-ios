import Foundation
import SwiftData

enum WorkerImportError: LocalizedError {
    case emptyFile
    case invalidJSON
    case invalidShape
    case noValidLog

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "JSON 文件为空"
        case .invalidJSON:
            return "JSON 不是有效格式，请确认文件完整"
        case .invalidShape:
            return "JSON 结构不符合 Worker 导出格式（需要包含 logs 数组）"
        case .noValidLog:
            return "JSON 中没有可导入的有效日志（请检查 created_at / trigger_primary / id）"
        }
    }
}

struct WorkerJsonImporter {
    struct TriggerReconcileRow: Identifiable {
        let trigger: TriggerPrimary
        let sourceCount: Int
        let importedCount: Int
        let localDelta: Int

        var id: String { trigger.rawValue }
    }

    struct DateRangeSummary {
        let start: Date
        let end: Date
    }

    struct ReconciliationReport {
        let sourceTotal: Int
        let sourceDateRange: DateRangeSummary?
        let duplicateCount: Int
        let invalidTriggerCount: Int

        let localBeforeTotal: Int
        let localAfterTotal: Int

        let triggerRows: [TriggerReconcileRow]
    }

    struct Result {
        let inserted: Int
        let skipped: Int
        let duplicateCount: Int
        let invalidTriggerCount: Int
        let cravingsInserted: Int
        let cravingsSkipped: Int
        let report: ReconciliationReport
    }

    let timeZone: TimeZone

    func importFromWorkerJSON(data: Data, context: ModelContext) throws -> Result {
        if data.isEmpty {
            throw WorkerImportError.emptyFile
        }

        let jsonObj: Any
        do {
            jsonObj = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw WorkerImportError.invalidJSON
        }

        let normalizedData: Data
        if let dict = jsonObj as? [String: Any] {
            guard dict["logs"] != nil else {
                throw WorkerImportError.invalidShape
            }
            normalizedData = data
        } else if let arr = jsonObj as? [[String: Any]] {
            let wrapped: [String: Any] = [
                "exported_at": ISO8601DateFormatter().string(from: Date()),
                "timezone": timeZone.identifier,
                "logs": arr
            ]
            normalizedData = try JSONSerialization.data(withJSONObject: wrapped)
        } else {
            throw WorkerImportError.invalidShape
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = try decoder.decode(WorkerExportPayload.self, from: normalizedData)
        let effectiveTimeZone = payload.timezone.flatMap(TimeZone.init(identifier:)) ?? timeZone
        let existing = try context.fetch(FetchDescriptor<SmokeLog>())
        let existingIDs = Set(existing.map { $0.id })

        let localBeforeTriggerMap = triggerCountMap(from: existing)

        var inserted = 0
        var skipped = 0
        var duplicateCount = 0
        var invalidTriggerCount = 0
        var invalidDateCount = 0
        var invalidIDCount = 0

        var insertedTriggerMap: [TriggerPrimary: Int] = [:]
        var sourceTriggerMap: [TriggerPrimary: Int] = [:]

        var cravingsInserted = 0
        var cravingsSkipped = 0
        let existingCravings = try context.fetch(FetchDescriptor<CravingEvent>())
        var existingCravingIDs = Set(existingCravings.map { $0.id })

        for item in payload.logs {
            let normalizedID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty else {
                invalidIDCount += 1
                skipped += 1
                continue
            }

            guard let createdAt = item.createdAt else {
                invalidDateCount += 1
                skipped += 1
                continue
            }

            guard let trigger = TriggerPrimary(rawValue: item.triggerPrimary) else {
                invalidTriggerCount += 1
                skipped += 1
                continue
            }

            sourceTriggerMap[trigger, default: 0] += 1

            if existingIDs.contains(normalizedID) {
                duplicateCount += 1
                skipped += 1
                continue
            }

            let log = SmokeLog(
                id: normalizedID,
                createdAt: createdAt,
                triggerPrimary: trigger,
                triggerSecondary: normalized(item.triggerSecondary),
                delayed10min: (item.delayed10min ?? 0) == 1,
                minutesSinceLast: item.minutesSinceLast,
                countInDay: max(1, item.countInDay ?? 1),
                isBackfill: (item.isBackfill ?? 0) == 1
            )

            context.insert(log)
            inserted += 1
            insertedTriggerMap[trigger, default: 0] += 1
        }

        for item in payload.cravings {
            let normalizedID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty else {
                cravingsSkipped += 1
                continue
            }
            guard let createdAt = item.createdAt,
                  let trigger = TriggerPrimary(rawValue: item.triggerPrimary) else {
                cravingsSkipped += 1
                continue
            }
            if existingCravingIDs.contains(normalizedID) {
                cravingsSkipped += 1
                continue
            }

            let statusRaw = (item.status ?? "pending").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let status = CravingEventStatus(rawValue: statusRaw) ?? .pending

            let event = CravingEvent(
                id: normalizedID,
                createdAt: createdAt,
                triggerPrimary: trigger,
                triggerSecondary: normalized(item.triggerSecondary),
                status: status,
                resolvedAt: item.resolvedAt,
                linkedSmokeLogID: normalized(item.linkedSmokeLogID)
            )
            context.insert(event)
            existingCravingIDs.insert(normalizedID)
            cravingsInserted += 1
        }

        if inserted > 0 || cravingsInserted > 0 {
            try context.save()
            try recalculateDerivedFields(context: context, timeZone: effectiveTimeZone)
        } else if invalidDateCount > 0 || invalidIDCount > 0 {
            throw WorkerImportError.noValidLog
        }

        let localAfter = try context.fetch(FetchDescriptor<SmokeLog>())
        let localAfterTriggerMap = triggerCountMap(from: localAfter)

        let rows = TriggerPrimary.allCases.map { trigger in
            TriggerReconcileRow(
                trigger: trigger,
                sourceCount: sourceTriggerMap[trigger, default: 0],
                importedCount: insertedTriggerMap[trigger, default: 0],
                localDelta: localAfterTriggerMap[trigger, default: 0] - localBeforeTriggerMap[trigger, default: 0]
            )
        }

        let report = ReconciliationReport(
            sourceTotal: payload.logs.count,
            sourceDateRange: sourceDateRange(from: payload.logs),
            duplicateCount: duplicateCount,
            invalidTriggerCount: invalidTriggerCount,
            localBeforeTotal: existing.count,
            localAfterTotal: localAfter.count,
            triggerRows: rows
        )

        return Result(
            inserted: inserted,
            skipped: skipped,
            duplicateCount: duplicateCount,
            invalidTriggerCount: invalidTriggerCount,
            cravingsInserted: cravingsInserted,
            cravingsSkipped: cravingsSkipped,
            report: report
        )
    }

    private func sourceDateRange(from logs: [WorkerExportLog]) -> DateRangeSummary? {
        let validDates = logs.compactMap(\.createdAt)
        guard let minDate = validDates.min(), let maxDate = validDates.max() else {
            return nil
        }
        return DateRangeSummary(start: minDate, end: maxDate)
    }

    private func triggerCountMap(from logs: [SmokeLog]) -> [TriggerPrimary: Int] {
        var map: [TriggerPrimary: Int] = [:]
        for log in logs {
            map[log.triggerPrimary, default: 0] += 1
        }
        return map
    }

    private func normalized(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recalculateDerivedFields(context: ModelContext, timeZone: TimeZone) throws {
        let logs = try context.fetch(FetchDescriptor<SmokeLog>()).sorted(by: { $0.createdAt < $1.createdAt })

        for idx in logs.indices {
            let current = logs[idx]
            let previous = idx > 0 ? logs[idx - 1] : nil

            if let previous {
                let minutes = max(0, Int(current.createdAt.timeIntervalSince(previous.createdAt) / 60))
                current.minutesSinceLast = minutes
            } else {
                current.minutesSinceLast = nil
            }

            let count = StatsService.countInDay(for: current.createdAt, logs: Array(logs[0...idx]), timeZone: timeZone)
            current.countInDay = max(1, count)
        }

        try context.save()
    }
}
