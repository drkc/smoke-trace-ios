import Foundation
import SwiftData

struct LogMaintenanceService {
    let timeZone: TimeZone

    func updateLog(
        in context: ModelContext,
        id: String,
        createdAt: Date,
        trigger: TriggerPrimary,
        triggerSecondary: String?,
        delayed10min: Bool
    ) throws {
        guard let target = try context.fetch(FetchDescriptor<SmokeLog>()).first(where: { $0.id == id }) else {
            return
        }

        target.createdAt = createdAt
        target.triggerPrimary = trigger
        target.triggerSecondary = normalized(triggerSecondary)
        target.delayed10min = delayed10min

        try recalculateDerivedFields(context: context)
    }

    func deleteLog(in context: ModelContext, id: String) throws {
        guard let target = try context.fetch(FetchDescriptor<SmokeLog>()).first(where: { $0.id == id }) else {
            return
        }
        context.delete(target)
        try recalculateDerivedFields(context: context)
    }

    func recalculateDerivedFields(context: ModelContext) throws {
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

    private func normalized(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
