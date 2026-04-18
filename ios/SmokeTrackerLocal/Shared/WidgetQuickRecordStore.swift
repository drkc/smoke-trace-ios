import Foundation

struct WidgetQuickRecordRequest: Codable, Identifiable {
    let id: String
    let triggerRawValue: String
    let createdAt: Date
}

struct WidgetQuickRecordPreferences: Codable {
    let small: [String]
    let medium: [String]
}

enum WidgetQuickRecordStore {
    private static let suiteName = "group.LRS7YLA5GN.eY3UkMP"
    private static let queueStorageKey = "widget.quick_record.queue"
    private static let preferenceStorageKey = "widget.quick_record.preferences"

    static let defaultSmall: [String] = ["idle_time", "after_meal"]
    static let defaultMedium: [String] = ["idle_time", "after_meal", "stress", "social"]

    private static let allowedTriggerRawValues: Set<String> = [
        "after_waking",
        "idle_time",
        "after_meal",
        "stress",
        "social",
        "driving",
        "work_transition",
        "other"
    ]

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

    static func loadPreferences() -> WidgetQuickRecordPreferences {
        guard let data = sharedDefaults().data(forKey: preferenceStorageKey),
              let decoded = try? JSONDecoder().decode(WidgetQuickRecordPreferences.self, from: data)
        else {
            return WidgetQuickRecordPreferences(small: defaultSmall, medium: defaultMedium)
        }
        return WidgetQuickRecordPreferences(
            small: normalized(rawValues: decoded.small, fallback: defaultSmall, maxCount: 2),
            medium: normalized(rawValues: decoded.medium, fallback: defaultMedium, maxCount: 4)
        )
    }

    static func loadActionButtonChoices() -> [String] {
        loadPreferences().medium
    }

    static func savePreferences(small: [String], medium: [String]) -> Bool {
        let normalizedSmall = normalized(rawValues: small, fallback: defaultSmall, maxCount: 2)
        let normalizedMedium = normalized(rawValues: medium, fallback: defaultMedium, maxCount: 4)

        guard Set(normalizedSmall).count == normalizedSmall.count,
              Set(normalizedMedium).count == normalizedMedium.count
        else {
            return false
        }

        let payload = WidgetQuickRecordPreferences(small: normalizedSmall, medium: normalizedMedium)
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        sharedDefaults().set(data, forKey: preferenceStorageKey)
        return true
    }

    private static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private static func readQueue() -> [WidgetQuickRecordRequest] {
        guard let data = sharedDefaults().data(forKey: queueStorageKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetQuickRecordRequest].self, from: data)) ?? []
    }

    private static func writeQueue(_ queue: [WidgetQuickRecordRequest]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        sharedDefaults().set(data, forKey: queueStorageKey)
    }

    private static func normalized(rawValues: [String], fallback: [String], maxCount: Int) -> [String] {
        let valid = rawValues
            .filter { allowedTriggerRawValues.contains($0) }
            .prefix(maxCount)

        if valid.count == maxCount {
            return Array(valid)
        }

        let merged = Array(valid) + fallback.filter { !valid.contains($0) }
        return Array(merged.prefix(maxCount))
    }
}
