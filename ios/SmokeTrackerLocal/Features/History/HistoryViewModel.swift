import Foundation
import SwiftData

struct EditableHistoryLog: Identifiable {
    let id: String
    var createdAt: Date
    var trigger: TriggerPrimary
    var triggerSecondary: String
    var delayed10min: Bool
}

struct EditableHistoryCraving: Identifiable {
    let id: String
    var createdAt: Date
    var trigger: TriggerPrimary
    var triggerSecondary: String
    var status: CravingEventStatus
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var selectedRange: HistoryRange = .week
    @Published var payload: HistoryPayload = .empty

    private let context: ModelContext
    private let service: HistoryAggregationService
    private let maintenance: LogMaintenanceService

    init(context: ModelContext, timeZone: TimeZone = .current) {
        self.context = context
        self.service = HistoryAggregationService(timeZone: timeZone)
        self.maintenance = LogMaintenanceService(timeZone: timeZone)
        reload()
    }

    func reload(anchor: Date = Date()) {
        let logs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []
        let cravings = (try? context.fetch(FetchDescriptor<CravingEvent>())) ?? []
        payload = service.buildPayload(range: selectedRange, anchor: anchor, logs: logs, cravings: cravings)
    }

    func loadEditableLog(id: String) -> EditableHistoryLog? {
        guard let log = (try? context.fetch(FetchDescriptor<SmokeLog>()))?.first(where: { $0.id == id }) else {
            return nil
        }
        return EditableHistoryLog(
            id: log.id,
            createdAt: log.createdAt,
            trigger: log.triggerPrimary,
            triggerSecondary: log.triggerSecondary ?? "",
            delayed10min: log.delayed10min
        )
    }

    func loadEditableCraving(id: String) -> EditableHistoryCraving? {
        guard let event = (try? context.fetch(FetchDescriptor<CravingEvent>()))?.first(where: { $0.id == id }) else {
            return nil
        }
        return EditableHistoryCraving(
            id: event.id,
            createdAt: event.createdAt,
            trigger: event.triggerPrimary,
            triggerSecondary: event.triggerSecondary ?? "",
            status: event.status
        )
    }

    @discardableResult
    func saveEditedLog(_ draft: EditableHistoryLog) -> String? {
        do {
            try maintenance.updateLog(
                in: context,
                id: draft.id,
                createdAt: draft.createdAt,
                trigger: draft.trigger,
                triggerSecondary: draft.triggerSecondary,
                delayed10min: draft.delayed10min
            )
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    func deleteLog(id: String) -> String? {
        do {
            try maintenance.deleteLog(in: context, id: id)
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    func saveEditedCraving(_ draft: EditableHistoryCraving) -> String? {
        do {
            guard let event = (try? context.fetch(FetchDescriptor<CravingEvent>()))?.first(where: { $0.id == draft.id }) else {
                return "未找到要编辑的起意记录"
            }
            event.createdAt = draft.createdAt
            event.triggerPrimary = draft.trigger
            let secondary = draft.triggerSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
            event.triggerSecondary = secondary.isEmpty ? nil : secondary
            event.status = draft.status
            event.resolvedAt = draft.status == .pending ? nil : (event.resolvedAt ?? draft.createdAt)
            if draft.status != .smoked {
                event.linkedSmokeLogID = nil
            }
            try context.save()
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    func deleteCraving(id: String) -> String? {
        do {
            guard let event = (try? context.fetch(FetchDescriptor<CravingEvent>()))?.first(where: { $0.id == id }) else {
                return "未找到要删除的起意记录"
            }
            context.delete(event)
            try context.save()
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var compareTitle: String {
        switch selectedRange {
        case .day: return "较昨日"
        case .week: return "较上周"
        case .month: return "较上月"
        }
    }

    var compareText: String {
        let c = payload.summary.comparePrevious
        guard let pct = c.deltaTotalPct else { return "无可比区间" }
        let deltaSign = c.deltaTotal >= 0 ? "+" : ""
        let pctSign = pct >= 0 ? "+" : ""
        return "\(deltaSign)\(c.deltaTotal)（\(pctSign)\(pct)%）"
    }

    var dailyAverageText: String {
        String(format: "%.1f 根", payload.summary.dailyAverage)
    }
}

extension HistoryPayload {
    static let empty = HistoryPayload(
        summary: HistorySummary(
            total: 0,
            averageInterval: nil,
            shortestInterval: nil,
            longestInterval: nil,
            dominantTrigger: nil,
            dailyAverage: 0,
            comparePrevious: ComparePreviousSummary(
                currentTotal: 0,
                previousTotal: 0,
                deltaTotal: 0,
                deltaTotalPct: nil,
                currentDailyAverage: 0,
                previousDailyAverage: 0,
                deltaDailyAverage: 0
            )
        ),
        dayCounts: [],
        triggerCounts: [],
        heatmapCells: [],
        rolling14DayCounts: [],
        details: []
    )
}
