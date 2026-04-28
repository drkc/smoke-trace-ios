import Foundation
import SwiftData

struct CravingFlowService {
    let logWriter: LogWriteService

    func createPendingCraving(
        in context: ModelContext,
        trigger: TriggerPrimary,
        triggerSecondary: String? = nil,
        at createdAt: Date = Date()
    ) throws -> CravingEvent {
        let allEvents = try context.fetch(FetchDescriptor<CravingEvent>())
        let olderPending = allEvents.filter { $0.status == .pending }
        for event in olderPending {
            event.status = .resisted
            event.resolvedAt = createdAt
        }

        let event = CravingEvent(
            createdAt: createdAt,
            triggerPrimary: trigger,
            triggerSecondary: normalizedSecondary(triggerSecondary),
            status: .pending
        )
        context.insert(event)
        try context.save()
        return event
    }

    func confirmSmokedNearestPending(
        in context: ModelContext,
        at smokedAt: Date = Date()
    ) throws -> (event: CravingEvent, log: SmokeLog, delayedEffective: Bool)? {
        let allEvents = try context.fetch(FetchDescriptor<CravingEvent>())
        guard let pending = allEvents
            .filter({ $0.status == .pending })
            .max(by: { $0.createdAt < $1.createdAt })
        else {
            return nil
        }

        let allLogs = try context.fetch(FetchDescriptor<SmokeLog>())
        let delayMinutes = max(0, Int(smokedAt.timeIntervalSince(pending.createdAt) / 60))
        let delayedEffective = delayMinutes >= 10

        let log = try logWriter.createLog(
            in: context,
            existingLogs: allLogs,
            trigger: pending.triggerPrimary,
            triggerSecondary: pending.triggerSecondary,
            delayed10min: delayedEffective,
            createdAt: smokedAt,
            isBackfill: false
        )

        pending.status = .smoked
        pending.resolvedAt = smokedAt
        pending.linkedSmokeLogID = log.id
        try context.save()

        return (pending, log, delayedEffective)
    }

    func latestPending(in context: ModelContext) -> CravingEvent? {
        let allEvents = (try? context.fetch(FetchDescriptor<CravingEvent>())) ?? []
        return allEvents
            .filter { $0.status == .pending }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    func cancelNearestPending(in context: ModelContext, at cancelledAt: Date = Date()) throws -> CravingEvent? {
        let allEvents = try context.fetch(FetchDescriptor<CravingEvent>())
        guard let pending = allEvents
            .filter({ $0.status == .pending })
            .max(by: { $0.createdAt < $1.createdAt })
        else {
            return nil
        }

        pending.status = .resisted
        pending.resolvedAt = cancelledAt
        try context.save()
        return pending
    }

    private func normalizedSecondary(_ text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }
}
