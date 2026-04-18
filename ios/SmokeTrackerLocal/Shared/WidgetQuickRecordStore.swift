import Foundation

struct WidgetQuickRecordRequest: Codable, Identifiable {
    let id: String
    let triggerRawValue: String
    let createdAt: Date
}

struct WidgetQuickRecordPreferences: Codable {
    let small: [String]
    let medium: [String]
    let actionOrder: [String]
    let actionEnabledCount: Int

    init(small: [String], medium: [String], actionOrder: [String], actionEnabledCount: Int) {
        self.small = small
        self.medium = medium
        self.actionOrder = actionOrder
        self.actionEnabledCount = actionEnabledCount
    }

    private enum CodingKeys: String, CodingKey {
        case small
        case medium
        case actionOrder
        case actionEnabledCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.small = try container.decodeIfPresent([String].self, forKey: .small) ?? WidgetQuickRecordStore.defaultSmall
        self.medium = try container.decodeIfPresent([String].self, forKey: .medium) ?? WidgetQuickRecordStore.defaultMedium
        self.actionOrder = try container.decodeIfPresent([String].self, forKey: .actionOrder) ?? WidgetQuickRecordStore.defaultActionOrder
        self.actionEnabledCount = try container.decodeIfPresent(Int.self, forKey: .actionEnabledCount) ?? WidgetQuickRecordStore.defaultActionEnabledCount
    }
}

struct ActionButtonCandidateConfig {
    let order: [String]
    let enabledCount: Int
}

enum WidgetQuickRecordStore {
    private static let suiteName = "group.LRS7YLA5GN.eY3UkMP"
    private static let queueStorageKey = "widget.quick_record.queue"
    private static let preferenceStorageKey = "widget.quick_record.preferences"

    static let defaultSmall: [String] = ["idle_time", "after_meal"]
    static let defaultMedium: [String] = ["idle_time", "after_meal", "stress", "social"]
    static let defaultActionOrder: [String] = [
        "after_waking",
        "idle_time",
        "after_meal",
        "stress",
        "social",
        "driving",
        "work_transition",
        "other"
    ]
    static let defaultActionEnabledCount: Int = 4

    private static let allowedTriggerRawValuesOrdered = defaultActionOrder
    private static let allowedTriggerRawValues: Set<String> = Set(allowedTriggerRawValuesOrdered)

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
            return WidgetQuickRecordPreferences(
                small: defaultSmall,
                medium: defaultMedium,
                actionOrder: defaultActionOrder,
                actionEnabledCount: defaultActionEnabledCount
            )
        }

        return WidgetQuickRecordPreferences(
            small: normalized(rawValues: decoded.small, fallback: defaultSmall, maxCount: 2),
            medium: normalized(rawValues: decoded.medium, fallback: defaultMedium, maxCount: 4),
            actionOrder: normalizedActionOrder(rawValues: decoded.actionOrder),
            actionEnabledCount: normalizedEnabledCount(decoded.actionEnabledCount)
        )
    }

    static func loadActionButtonConfig() -> ActionButtonCandidateConfig {
        let prefs = loadPreferences()
        return ActionButtonCandidateConfig(order: prefs.actionOrder, enabledCount: prefs.actionEnabledCount)
    }

    static func loadActionButtonChoices() -> [String] {
        let config = loadActionButtonConfig()
        return Array(config.order.prefix(config.enabledCount))
    }

    static func saveActionButtonConfig(order: [String], enabledCount: Int) -> Bool {
        let current = loadPreferences()
        return savePreferences(
            small: current.small,
            medium: current.medium,
            actionOrder: order,
            actionEnabledCount: enabledCount
        )
    }

    static func savePreferences(
        small: [String],
        medium: [String],
        actionOrder: [String]? = nil,
        actionEnabledCount: Int? = nil
    ) -> Bool {
        let normalizedSmall = normalized(rawValues: small, fallback: defaultSmall, maxCount: 2)
        let normalizedMedium = normalized(rawValues: medium, fallback: defaultMedium, maxCount: 4)

        guard Set(normalizedSmall).count == normalizedSmall.count,
              Set(normalizedMedium).count == normalizedMedium.count
        else {
            return false
        }

        let current = loadPreferences()
        let normalizedOrder = normalizedActionOrder(rawValues: actionOrder ?? current.actionOrder)
        let normalizedCount = normalizedEnabledCount(actionEnabledCount ?? current.actionEnabledCount)

        let payload = WidgetQuickRecordPreferences(
            small: normalizedSmall,
            medium: normalizedMedium,
            actionOrder: normalizedOrder,
            actionEnabledCount: normalizedCount
        )
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

    private static func normalizedActionOrder(rawValues: [String]) -> [String] {
        var seen = Set<String>()
        var valid = rawValues.filter { raw in
            guard allowedTriggerRawValues.contains(raw), !seen.contains(raw) else { return false }
            seen.insert(raw)
            return true
        }

        for raw in allowedTriggerRawValuesOrdered where !seen.contains(raw) {
            valid.append(raw)
            seen.insert(raw)
        }

        return Array(valid.prefix(allowedTriggerRawValuesOrdered.count))
    }

    private static func normalizedEnabledCount(_ value: Int) -> Int {
        min(max(value, 1), allowedTriggerRawValuesOrdered.count)
    }
}
