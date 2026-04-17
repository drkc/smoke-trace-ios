import Foundation

struct WidgetQuickRecordRequest: Codable, Identifiable {
    let id: String
    let triggerRawValue: String
    let createdAt: Date
}

enum WidgetQuickRecordStore {
    private static let suiteName = "group.LRS7YLA5GN.eY3UkMP"
    private static let storageKey = "widget.quick_record.queue"

    static func enqueue(triggerRawValue: String, createdAt: Date = Date()) {
        var queue = readQueue()
        queue.append(WidgetQuickRecordRequest(id: UUID().uuidString, triggerRawValue: triggerRawValue, createdAt: createdAt))
        writeQueue(queue)
    }

    static func drain() -> [WidgetQuickRecordRequest] {
        let queue = readQueue()
        writeQueue([])
        return queue.sorted(by: { $0.createdAt < $1.createdAt })
    }

    static func pendingCount() -> Int {
        readQueue().count
    }

    private static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static func readQueue() -> [WidgetQuickRecordRequest] {
        guard let data = sharedDefaults().data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetQuickRecordRequest].self, from: data)) ?? []
    }

    private static func writeQueue(_ queue: [WidgetQuickRecordRequest]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        sharedDefaults().set(data, forKey: storageKey)
    }
}
