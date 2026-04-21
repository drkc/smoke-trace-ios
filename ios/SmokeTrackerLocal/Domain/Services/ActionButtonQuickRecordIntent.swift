import Foundation
import AppIntents
import WidgetKit

enum ActionButtonTriggerOption: String, AppEnum, CaseIterable {
    case afterWaking = "after_waking"
    case idleTime = "idle_time"
    case afterMeal = "after_meal"
    case stress = "stress"
    case social = "social"
    case driving = "driving"
    case workTransition = "work_transition"
    case other = "other"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "触发原因")

    static var caseDisplayRepresentations: [ActionButtonTriggerOption: DisplayRepresentation] = [
        .afterWaking: "起床后",
        .idleTime: "空档",
        .afterMeal: "饭后",
        .stress: "压力",
        .social: "社交",
        .driving: "开车",
        .workTransition: "工作间隙",
        .other: "其他"
    ]

    static func from(raw: String) -> ActionButtonTriggerOption {
        ActionButtonTriggerOption(rawValue: raw) ?? .idleTime
    }

    var zhLabel: String {
        switch self {
        case .afterWaking: return "起床后"
        case .idleTime: return "空档"
        case .afterMeal: return "饭后"
        case .stress: return "压力"
        case .social: return "社交"
        case .driving: return "开车"
        case .workTransition: return "工作间隙"
        case .other: return "其他"
        }
    }
}

struct ActionButtonTriggerOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [ActionButtonTriggerOption] {
        let rawChoices = WidgetQuickRecordStore.loadActionButtonChoices()
        var seen = Set<String>()
        var mapped: [ActionButtonTriggerOption] = []
        for raw in rawChoices {
            guard !seen.contains(raw) else { continue }
            seen.insert(raw)
            mapped.append(ActionButtonTriggerOption.from(raw: raw))
        }
        if !mapped.isEmpty {
            return mapped
        }
        return WidgetQuickRecordStore.defaultMedium.map(ActionButtonTriggerOption.from(raw:))
    }
}

struct ActionButtonQuickRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录（系统弹层）"
    static var description = IntentDescription("不拉起 App，使用系统选择弹层进行快速记录")
    static var openAppWhenRun = false

    @Parameter(
        title: "触发原因",
        requestValueDialog: IntentDialog("请选择这次的触发原因"),
        optionsProvider: ActionButtonTriggerOptionsProvider()
    )
    var trigger: ActionButtonTriggerOption?

    init() {
        self.trigger = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("记录一根")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let options = try await ActionButtonTriggerOptionsProvider().results()
        let selected = try await $trigger.requestDisambiguation(
            among: options,
            dialog: IntentDialog("请选择这次的触发原因")
        )

        let eventTime = Date()
        let wrote = QuickRecordPersistence.writeDirect(triggerRawValue: selected.rawValue, createdAt: eventTime)
        if !wrote {
            WidgetQuickRecordStore.enqueue(triggerRawValue: selected.rawValue, createdAt: eventTime)
        }

        WidgetCenter.shared.reloadAllTimelines()
        if wrote {
            return .result(dialog: IntentDialog("已记录：\(selected.zhLabel)"))
        }
        return .result(dialog: IntentDialog("已加入待入库队列：\(selected.zhLabel)"))
    }
}

struct ActionButtonLaunchPickerIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录（拉起 App 面板）"
    static var description = IntentDescription("拉起 App 后按设置位置显示选择面板：上置/居中/下置")
    static var openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("打开 App 快速记录")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetQuickRecordStore.requestLaunchPickerFromActionButton()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog("已打开记录面板"))
    }
}

struct SmokeTrackerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActionButtonQuickRecordIntent(),
            phrases: [
                "在 \(.applicationName) 快速记录",
                "用 \(.applicationName) 记录一根"
            ],
            shortTitle: "快速记录（系统）",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: ActionButtonLaunchPickerIntent(),
            phrases: [
                "在 \(.applicationName) 打开记录面板",
                "用 \(.applicationName) 拉起记录"
            ],
            shortTitle: "快速记录（拉起）",
            systemImageName: "rectangle.portrait.and.arrow.right"
        )
    }
}
