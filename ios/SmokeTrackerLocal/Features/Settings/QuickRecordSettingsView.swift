import SwiftUI
import SwiftData
import WidgetKit

struct QuickRecordSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSetting]

    @State private var suggestionEngineToggle = true
    @State private var timezoneSelection = TimeZone.current.identifier

    @State private var widgetSmallPrimary = "idle_time"
    @State private var widgetSmallSecondary = "after_meal"
    @State private var widgetMedium1 = "idle_time"
    @State private var widgetMedium2 = "after_meal"
    @State private var widgetMedium3 = "stress"
    @State private var widgetMedium4 = "social"

    @State private var actionExecutionMode: ActionButtonExecutionMode = .systemChooser
    @State private var actionPickerPosition: ActionButtonPickerPosition = .center
    @State private var actionCandidateOrder: [String] = TriggerPrimary.allCases.map(\.rawValue)
    @State private var actionCandidateEnabledCount = 4

    @State private var showAlert = false
    @State private var alertMessage = ""

    private let timezoneOptions = ["Asia/Hong_Kong", "Asia/Shanghai", "UTC"]

    var body: some View {
        Form {
            Section("行为偏好") {
                Toggle("开启即时提示", isOn: Binding(
                    get: { suggestionEngineToggle },
                    set: { setSuggestionEngineEnabled($0) }
                ))

                Picker("统计时区", selection: Binding(
                    get: { timezoneSelection },
                    set: { setTimezoneIdentifier($0) }
                )) {
                    ForEach(timezonePickerOptions, id: \.self) { id in
                        Text(timezoneLabel(for: id)).tag(id)
                    }
                }

                AppHintText(text: "仅影响统计口径，不修改原始记录")
            }

            Section("小组件快捷触发") {
                Picker("小号按钮 1", selection: $widgetSmallPrimary) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }

                Picker("小号按钮 2", selection: $widgetSmallSecondary) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }

                Picker("中号按钮 1", selection: $widgetMedium1) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }

                Picker("中号按钮 2", selection: $widgetMedium2) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }

                Picker("中号按钮 3", selection: $widgetMedium3) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }

                Picker("中号按钮 4", selection: $widgetMedium4) {
                    ForEach(widgetTriggerOptions, id: \.self) { raw in
                        Text(widgetOptionLabel(raw)).tag(raw)
                    }
                }
            }

            Section("Action Button") {
                Picker("执行方式", selection: $actionExecutionMode) {
                    ForEach(ActionButtonExecutionMode.allCases, id: \.rawValue) { mode in
                        Text(mode.zhLabel).tag(mode)
                    }
                }

                Picker("拉起面板位置", selection: $actionPickerPosition) {
                    ForEach(ActionButtonPickerPosition.allCases, id: \.rawValue) { position in
                        Text(position.zhLabel).tag(position)
                    }
                }
                .disabled(actionExecutionMode != .launchAppPicker)

                if actionExecutionMode == .launchAppPicker {
                    AppHintText(text: "请在系统 Action Button 绑定：快速记录（拉起 App 面板）")
                } else {
                    AppHintText(text: "请在系统 Action Button 绑定：快速记录（系统）")
                }

                NavigationLink("配置待选列表（1-8 项，可拖动）") {
                    ActionButtonCandidateConfigView(
                        order: $actionCandidateOrder,
                        enabledCount: $actionCandidateEnabledCount,
                        labelForRaw: widgetOptionLabel
                    )
                }

                AppHintText(text: "当前待选：\(actionCandidateEnabledCount) 项（\(actionCandidatePreviewText)）")
            }

            Section {
                Button("保存快捷记录设置") {
                    saveQuickRecordSettings()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("快捷记录")
        .alert("快捷记录设置", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            _ = AppSetting.fetchOrCreate(in: modelContext)
            syncStateFromStorage()
        }
        .onChange(of: settings.count) { _, _ in
            syncStateFromStorage()
        }
    }

    private var setting: AppSetting {
        settings.first ?? AppSetting.fetchOrCreate(in: modelContext)
    }

    private var timezonePickerOptions: [String] {
        let current = setting.timezoneIdentifier
        var options = timezoneOptions
        if !options.contains(current) {
            options.insert(current, at: 0)
        }
        return options
    }

    private var widgetTriggerOptions: [String] {
        TriggerPrimary.allCases.map(\.rawValue)
    }

    private var actionCandidatePreviewText: String {
        let count = min(max(actionCandidateEnabledCount, 1), actionCandidateOrder.count)
        let visible = actionCandidateOrder.prefix(count).map { widgetOptionLabel($0) }
        return visible.joined(separator: "、")
    }

    private func timezoneLabel(for identifier: String) -> String {
        switch identifier {
        case "Asia/Hong_Kong": return "香港时间（Asia/Hong_Kong）"
        case "Asia/Shanghai": return "北京时间（Asia/Shanghai）"
        case "UTC": return "UTC"
        default: return identifier
        }
    }

    private func widgetOptionLabel(_ raw: String) -> String {
        TriggerPrimary(rawValue: raw)?.zhLabel ?? raw
    }

    private func syncStateFromStorage() {
        suggestionEngineToggle = setting.suggestionEngineEnabled
        timezoneSelection = setting.timezoneIdentifier

        let prefs = WidgetQuickRecordStore.loadPreferences()
        let small = prefs.small + WidgetQuickRecordStore.defaultSmall
        widgetSmallPrimary = small[0]
        widgetSmallSecondary = small[1]

        let medium = prefs.medium + WidgetQuickRecordStore.defaultMedium
        widgetMedium1 = medium[0]
        widgetMedium2 = medium[1]
        widgetMedium3 = medium[2]
        widgetMedium4 = medium[3]

        let actionConfig = WidgetQuickRecordStore.loadActionButtonConfig()
        actionCandidateOrder = actionConfig.order
        actionCandidateEnabledCount = actionConfig.enabledCount
        actionExecutionMode = WidgetQuickRecordStore.loadActionButtonExecutionMode()
        actionPickerPosition = WidgetQuickRecordStore.loadActionButtonPickerPosition()
    }

    private func setSuggestionEngineEnabled(_ enabled: Bool) {
        setting.suggestionEngineEnabled = enabled
        saveSetting()
    }

    private func setTimezoneIdentifier(_ identifier: String) {
        setting.timezoneIdentifier = identifier
        saveSetting()
    }

    private func saveQuickRecordSettings() {
        let small = [widgetSmallPrimary, widgetSmallSecondary]
        if Set(small).count != small.count {
            alertMessage = "小号组件的两个按钮不能重复"
            showAlert = true
            return
        }

        let medium = [widgetMedium1, widgetMedium2, widgetMedium3, widgetMedium4]
        if Set(medium).count != medium.count {
            alertMessage = "中号组件的四个按钮不能重复"
            showAlert = true
            return
        }

        let ok = WidgetQuickRecordStore.savePreferences(
            small: small,
            medium: medium,
            actionOrder: actionCandidateOrder,
            actionEnabledCount: actionCandidateEnabledCount,
            actionExecutionMode: actionExecutionMode,
            actionPickerPosition: actionPickerPosition
        )

        if ok {
            WidgetCenter.shared.reloadAllTimelines()
            alertMessage = "快捷记录设置已保存"
        } else {
            alertMessage = "保存失败，请重试"
        }
        showAlert = true
    }

    private func saveSetting() {
        do {
            try modelContext.save()
        } catch {
            alertMessage = "设置保存失败：\(error.localizedDescription)"
            showAlert = true
        }
    }
}
