import Foundation
import SwiftData

struct LogWriteService {
    let timeZone: TimeZone

    func createLog(
        in context: ModelContext,
        existingLogs: [SmokeLog],
        trigger: TriggerPrimary,
        triggerSecondary: String?,
        delayed10min: Bool,
        createdAt: Date,
        isBackfill: Bool,
        preferredID: String? = nil
    ) throws -> SmokeLog {
        let minutes = StatsService.minutesSinceLast(for: createdAt, logs: existingLogs)
        let count = StatsService.countInDay(for: createdAt, logs: existingLogs, timeZone: timeZone) + 1

        let log = SmokeLog(
            id: normalizedID(preferredID),
            createdAt: createdAt,
            triggerPrimary: trigger,
            triggerSecondary: normalizedSecondary(triggerSecondary),
            delayed10min: delayed10min,
            minutesSinceLast: minutes,
            countInDay: count,
            isBackfill: isBackfill
        )

        context.insert(log)
        try context.save()
        return log
    }

    func markDelayed(in context: ModelContext, log: SmokeLog) throws {
        log.delayed10min = true
        try context.save()
    }

    func revertLatest(in context: ModelContext, logs: [SmokeLog]) throws -> Bool {
        guard let latest = logs.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            return false
        }
        context.delete(latest)
        try context.save()
        return true
    }

    private func normalizedSecondary(_ text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private func normalizedID(_ id: String?) -> String {
        guard let raw = id?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return UUID().uuidString
        }
        return raw
    }
}
