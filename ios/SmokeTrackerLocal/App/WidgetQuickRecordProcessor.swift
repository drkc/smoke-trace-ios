import Foundation
import SwiftData
import WidgetKit

enum WidgetQuickRecordProcessor {
    @discardableResult
    static func processPendingRequests(in context: ModelContext) -> Int {
        let requests = WidgetQuickRecordStore.readAllRequests()
        guard !requests.isEmpty else { return 0 }

        let setting = AppSetting.fetchOrCreate(in: context)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current
        let writer = LogWriteService(timeZone: timeZone)

        var logs = (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []
        var existingIDs = Set(logs.map(\.id))
        var processedIDs = Set<String>()
        var insertedCount = 0

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
                insertedCount += 1
            } catch {
                continue
            }
        }

        WidgetQuickRecordStore.removeRequests(ids: processedIDs)
        WidgetCenter.shared.reloadAllTimelines()
        return insertedCount
    }
}
