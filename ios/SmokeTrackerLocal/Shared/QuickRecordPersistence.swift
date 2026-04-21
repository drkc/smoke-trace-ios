import Foundation
import SwiftData

enum QuickRecordPersistence {
    static func writeDirect(triggerRawValue: String, createdAt: Date = Date()) -> Bool {
        guard let trigger = TriggerPrimary(rawValue: triggerRawValue) else {
            return false
        }

        let context = ModelContext(SharedModelContainerFactory.shared)
        let setting = AppSetting.fetchOrCreate(in: context)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current
        let writer = LogWriteService(timeZone: timeZone)
        let existingLogs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []

        do {
            _ = try writer.createLog(
                in: context,
                existingLogs: existingLogs,
                trigger: trigger,
                triggerSecondary: nil,
                delayed10min: false,
                createdAt: createdAt,
                isBackfill: false
            )
            return true
        } catch {
            return false
        }
    }
}
