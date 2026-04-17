import Foundation
import SwiftData
import WidgetKit

enum WidgetQuickRecordProcessor {
    static func processPendingRequests(in context: ModelContext) {
        let requests = WidgetQuickRecordStore.drain()
        guard !requests.isEmpty else { return }

        let setting = AppSetting.fetchOrCreate(in: context)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current
        let writer = LogWriteService(timeZone: timeZone)

        var logs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []

        for request in requests {
            guard let trigger = TriggerPrimary(rawValue: request.triggerRawValue) else { continue }
            do {
                let log = try writer.createLog(
                    in: context,
                    existingLogs: logs,
                    trigger: trigger,
                    triggerSecondary: nil,
                    delayed10min: false,
                    createdAt: request.createdAt,
                    isBackfill: false
                )
                logs.append(log)
            } catch {
                continue
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
