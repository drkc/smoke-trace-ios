import Foundation

struct WidgetQuickRecordRequest: Codable, Identifiable {
    let id: String
    let triggerRawValue: String
    let createdAt: Date
}

struct WidgetQuickRecordActionFeedback: Codable {
    let message: String
    let createdAt: Date
    let isDirectWrite: Bool
}

enum ActionButtonExecutionMode: String, Codable, CaseIterable {
    case systemChooser = "system_chooser"
    case launchAppPicker = "launch_app_picker"

    var zhLabel: String {
        switch self {
        case .systemChooser: return "系统弹层（不拉起）"
        case .launchAppPicker: return "拉起 App 面板"
        }
    }
}

enum ActionButtonPickerPosition: String, Codable, CaseIterable {
    case top
    case center
    case bottom

    var zhLabel: String {
        switch self {
        case .top: return "上置"
        case .center: return "居中"
        case .bottom: return "下置"
        }
    }
}

struct WidgetQuickRecordPreferences: Codable {
    let small: [String]
    let medium: [String]
    let actionOrder: [String]
    let actionEnabledCount: Int
    let actionExecutionModeRaw: String
    let actionPickerPositionRaw: String

    init(
        small: [String],
        medium: [String],
        actionOrder: [String],
        actionEnabledCount: Int,
        actionExecutionMode: ActionButtonExecutionMode,
        actionPickerPosition: ActionButtonPickerPosition
    ) {
        self.small = small
        self.medium = medium
        self.actionOrder = actionOrder
        self.actionEnabledCount = actionEnabledCount
        self.actionExecutionModeRaw = actionExecutionMode.rawValue
        self.actionPickerPositionRaw = actionPickerPosition.rawValue
    }

    private enum CodingKeys: String, CodingKey {
        case small
        case medium
        case actionOrder
        case actionEnabledCount
        case actionExecutionModeRaw
        case actionPickerPositionRaw
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.small = try container.decodeIfPresent([String].self, forKey: .small) ?? WidgetQuickRecordStore.defaultSmall
        self.medium = try container.decodeIfPresent([String].self, forKey: .medium) ?? WidgetQuickRecordStore.defaultMedium
        self.actionOrder = try container.decodeIfPresent([String].self, forKey: .actionOrder) ?? WidgetQuickRecordStore.defaultActionOrder
        self.actionEnabledCount = try container.decodeIfPresent(Int.self, forKey: .actionEnabledCount) ?? WidgetQuickRecordStore.defaultActionEnabledCount
        self.actionExecutionModeRaw = try container.decodeIfPresent(String.self, forKey: .actionExecutionModeRaw)
            ?? WidgetQuickRecordStore.defaultActionExecutionMode.rawValue
        self.actionPickerPositionRaw = try container.decodeIfPresent(String.self, forKey: .actionPickerPositionRaw)
            ?? WidgetQuickRecordStore.defaultActionPickerPosition.rawValue
    }
}

struct ActionButtonCandidateConfig {
    let order: [String]
    let enabledCount: Int
}

enum WidgetQuickRecordStore {
    private static let suiteName = SharedModelContainerFactory.appGroupIdentifier
    private static let queueStorageKey = "widget.quick_record.queue"
    private static let preferenceStorageKey = "widget.quick_record.preferences"
    private static let launchPickerRequestKey = "action_button.launch_picker.request"
    private static let latestActionFeedbackStorageKey = "widget.quick_record.latest_action_feedback"
    private static let feedbackDisplayDuration: TimeInterval = 8

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
    static let defaultActionExecutionMode: ActionButtonExecutionMode = .systemChooser
    static let defaultActionPickerPosition: ActionButtonPickerPosition = .center

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

    static func readAllRequests() -> [WidgetQuickRecordRequest] {
        readQueue().sorted(by: { $0.createdAt < $1.createdAt })
    }

    static func removeRequests(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let remained = readQueue().filter { !ids.contains($0.id) }
        writeQueue(remained)
    }

    static func pendingCount() -> Int {
        readQueue().count
    }

    static func saveLatestActionFeedback(triggerRawValue: String, createdAt: Date, isDirectWrite: Bool) {
        let label = TriggerPrimary(rawValue: triggerRawValue)?.zhLabel ?? "未知"
        let message = isDirectWrite ? "已记录：\(label)" : "已加入待入库：\(label)"
        let payload = WidgetQuickRecordActionFeedback(
            message: message,
            createdAt: createdAt,
            isDirectWrite: isDirectWrite
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        sharedDefaults().set(data, forKey: latestActionFeedbackStorageKey)
    }

    static func loadLatestActionFeedback(now: Date = Date()) -> WidgetQuickRecordActionFeedback? {
        guard let data = sharedDefaults().data(forKey: latestActionFeedbackStorageKey),
              let feedback = try? JSONDecoder().decode(WidgetQuickRecordActionFeedback.self, from: data)
        else {
            return nil
        }

        if now.timeIntervalSince(feedback.createdAt) > feedbackDisplayDuration {
            sharedDefaults().removeObject(forKey: latestActionFeedbackStorageKey)
            return nil
        }

        return feedback
    }

    static func loadPreferences() -> WidgetQuickRecordPreferences {
        guard let data = sharedDefaults().data(forKey: preferenceStorageKey),
              let decoded = try? JSONDecoder().decode(WidgetQuickRecordPreferences.self, from: data)
        else {
            return WidgetQuickRecordPreferences(
                small: defaultSmall,
                medium: defaultMedium,
                actionOrder: defaultActionOrder,
                actionEnabledCount: defaultActionEnabledCount,
                actionExecutionMode: defaultActionExecutionMode,
                actionPickerPosition: defaultActionPickerPosition
            )
        }

        return WidgetQuickRecordPreferences(
            small: normalized(rawValues: decoded.small, fallback: defaultSmall, maxCount: 2),
            medium: normalized(rawValues: decoded.medium, fallback: defaultMedium, maxCount: 4),
            actionOrder: normalizedActionOrder(rawValues: decoded.actionOrder),
            actionEnabledCount: normalizedEnabledCount(decoded.actionEnabledCount),
            actionExecutionMode: ActionButtonExecutionMode(rawValue: decoded.actionExecutionModeRaw) ?? defaultActionExecutionMode,
            actionPickerPosition: ActionButtonPickerPosition(rawValue: decoded.actionPickerPositionRaw) ?? defaultActionPickerPosition
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

    static func loadActionButtonExecutionMode() -> ActionButtonExecutionMode {
        let raw = loadPreferences().actionExecutionModeRaw
        return ActionButtonExecutionMode(rawValue: raw) ?? defaultActionExecutionMode
    }

    static func loadActionButtonPickerPosition() -> ActionButtonPickerPosition {
        let raw = loadPreferences().actionPickerPositionRaw
        return ActionButtonPickerPosition(rawValue: raw) ?? defaultActionPickerPosition
    }

    static func requestLaunchPickerFromActionButton() {
        sharedDefaults().set(UUID().uuidString, forKey: launchPickerRequestKey)
    }

    static func hasPendingLaunchPickerRequest() -> Bool {
        (sharedDefaults().string(forKey: launchPickerRequestKey)?.isEmpty == false)
    }

    static func consumeLaunchPickerRequest() -> Bool {
        guard hasPendingLaunchPickerRequest() else { return false }
        sharedDefaults().removeObject(forKey: launchPickerRequestKey)
        return true
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
        actionEnabledCount: Int? = nil,
        actionExecutionMode: ActionButtonExecutionMode? = nil,
        actionPickerPosition: ActionButtonPickerPosition? = nil
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
        let normalizedMode = actionExecutionMode ?? ActionButtonExecutionMode(rawValue: current.actionExecutionModeRaw) ?? defaultActionExecutionMode
        let normalizedPosition = actionPickerPosition ?? ActionButtonPickerPosition(rawValue: current.actionPickerPositionRaw) ?? defaultActionPickerPosition

        let payload = WidgetQuickRecordPreferences(
            small: normalizedSmall,
            medium: normalizedMedium,
            actionOrder: normalizedOrder,
            actionEnabledCount: normalizedCount,
            actionExecutionMode: normalizedMode,
            actionPickerPosition: normalizedPosition
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
