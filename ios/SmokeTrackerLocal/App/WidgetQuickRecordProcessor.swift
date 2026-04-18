import Foundation
import SwiftData
import WidgetKit

enum WidgetQuickRecordProcessor {
    static func processPendingRequests(in context: ModelContext) {
        let requests = WidgetQuickRecordStore.readAllRequests()
        guard !requests.isEmpty else { return }

        let setting = AppSetting.fetchOrCreate(in: context)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current
        let writer = LogWriteService(timeZone: timeZone)

        var logs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []
        var existingIDs = Set(logs.map(\.id))
        var processedIDs = Set<String>()

        for request in requests {
            if existingIDs.contains(request.id) {
                processedIDs.insert(request.id)
                continue
            }

            guard let trigger = TriggerPrimary(rawValue: request.triggerRawValue) else {
                processedIDs.insert(request.id)
                continue
            }

            do {
                let log = try writer.createLog(
                    in: context,
                    existingLogs: logs,
                    trigger: trigger,
                    triggerSecondary: nil,
                    delayed10min: false,
                    createdAt: request.createdAt,
                    isBackfill: false,
                    preferredID: request.id
                )
                logs.append(log)
                existingIDs.insert(log.id)
                processedIDs.insert(request.id)
            } catch {
                continue
            }
        }

        WidgetQuickRecordStore.removeRequests(ids: processedIDs)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
