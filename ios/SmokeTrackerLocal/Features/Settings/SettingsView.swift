import SwiftUI
import SwiftData
import WidgetKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSetting]

    @State private var showImport = false
    @State private var exportMessage: String?
    @State private var showClearConfirm = false

    @State private var pinEnabledToggle = false
    @State private var biometricsToggle = false
    @State private var suggestionEngineToggle = true
    @State private var timezoneSelection = TimeZone.current.identifier
    @State private var showPinSetup = false
    @State private var widgetSmallPrimary = "idle_time"
    @State private var widgetSmallSecondary = "after_meal"
    @State private var widgetMedium1 = "idle_time"
    @State private var widgetMedium2 = "after_meal"
    @State private var widgetMedium3 = "stress"
    @State private var widgetMedium4 = "social"
    @State private var actionCandidateOrder: [String] = TriggerPrimary.allCases.map(\.rawValue)
    @State private var actionCandidateEnabledCount = 4
    @State private var showWidgetConfigDuplicateAlert = false
    @State private var widgetConfigAlertMessage = ""

    private let timezoneOptions = [
        "Asia/Hong_Kong",
        "Asia/Shanghai",
        "UTC"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    Toggle("启用 PIN 锁", isOn: Binding(
                        get: { pinEnabledToggle },
                        set: { setPinEnabled($0) }
                    ))

                    Toggle("启用生物识别", isOn: Binding(
                        get: { biometricsToggle },
                        set: { setBiometricsEnabled($0) }
                    ))
                    .disabled(!pinEnabledToggle)

                    if pinEnabledToggle {
                        Button("修改 PIN") {
                            showPinSetup = true
                        }
                    }
                }

                Section("行为") {
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

                    Text("仅影响统计口径，不修改原始记录")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

                    NavigationLink("配置 Action Button 待选列表") {
                        ActionButtonCandidateConfigView(
                            order: $actionCandidateOrder,
                            enabledCount: $actionCandidateEnabledCount,
                            labelForRaw: widgetOptionLabel
                        )
                    }

                    Text("当前待选：\(actionCandidateEnabledCount) 项（\(actionCandidatePreviewText)）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("保存小组件触发设置") {
                        saveWidgetQuickActions()
                    }

                    Text("规则：小号 2 按钮横向排列；中号 4 按钮。Action Button 待选列表可在上方页面配置（1-8 项、可拖动排序）。小号/中号每组不允许重复，重复将弹窗并拒绝保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据迁移") {
                    Button("导入 Worker 导出 JSON") {
                        showImport = true
                    }
                }

                Section("导出") {
                    Button("导出 JSON 到 Documents") {
                        exportJSON()
                    }
                    Button("导出 CSV 到 Documents") {
                        exportCSV()
                    }
                    if let exportMessage {
                        Text(exportMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("危险操作") {
                    Button("清空所有记录", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showImport) {
                ImportView()
            }
            .sheet(isPresented: $showPinSetup) {
                PinSetupView(title: pinEnabledToggle ? "修改 PIN" : "设置 PIN") { newPin in
                    savePIN(newPin)
                }
            }
            .confirmationDialog("确认清空所有记录？", isPresented: $showClearConfirm) {
                Button("确认清空", role: .destructive) {
                    clearAll()
                }
                Button("取消", role: .cancel) {}
            }
            .alert("小组件设置未保存", isPresented: $showWidgetConfigDuplicateAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(widgetConfigAlertMessage)
            }
            .onAppear {
                _ = AppSetting.fetchOrCreate(in: modelContext)
                syncToggleState()
            }
            .onChange(of: settings.count) { _, _ in
                syncToggleState()
            }
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
        case "Asia/Hong_Kong":
            return "香港时间（Asia/Hong_Kong）"
        case "Asia/Shanghai":
            return "北京时间（Asia/Shanghai）"
        case "UTC":
            return "UTC"
        default:
            return identifier
        }
    }

    private func widgetOptionLabel(_ raw: String) -> String {
        TriggerPrimary(rawValue: raw)?.zhLabel ?? raw
    }

    private func syncToggleState() {
        pinEnabledToggle = setting.pinEnabled
        biometricsToggle = setting.pinEnabled && setting.biometricsEnabled
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
    }

    private func setPinEnabled(_ enabled: Bool) {
        if enabled {
            showPinSetup = true
            return
        }

        setting.pinEnabled = false
        setting.biometricsEnabled = false
        saveSetting()
        syncToggleState()
    }

    private func setBiometricsEnabled(_ enabled: Bool) {
        guard pinEnabledToggle else {
            biometricsToggle = false
            return
        }

        if !enabled {
            setting.biometricsEnabled = false
            saveSetting()
            syncToggleState()
            return
        }

        guard AppLockService.canEvaluateBiometrics() else {
            exportMessage = "当前设备不可用生物识别"
            biometricsToggle = false
            return
        }

        Task {
            let ok = await AppLockService.authenticateWithBiometrics(reason: "启用生物识别解锁")
            await MainActor.run {
                if ok {
                    setting.biometricsEnabled = true
                    saveSetting()
                    syncToggleState()
                } else {
                    exportMessage = "生物识别验证未通过，未启用"
                    biometricsToggle = false
                }
            }
        }
    }

    private func setSuggestionEngineEnabled(_ enabled: Bool) {
        setting.suggestionEngineEnabled = enabled
        saveSetting()
        syncToggleState()
    }

    private func setTimezoneIdentifier(_ identifier: String) {
        setting.timezoneIdentifier = identifier
        saveSetting()
        syncToggleState()
    }

    private func savePIN(_ pin: String) {
        setting.pinHash = AppLockService.hashPIN(pin)
        setting.pinEnabled = true
        saveSetting()
        syncToggleState()
        exportMessage = "PIN 已保存"
    }

    private func saveWidgetQuickActions() {
        let small = [widgetSmallPrimary, widgetSmallSecondary]
        if Set(small).count != small.count {
            widgetConfigAlertMessage = "小号组件的两个按钮不能重复，请调整后再保存。"
            showWidgetConfigDuplicateAlert = true
            return
        }

        let medium = [widgetMedium1, widgetMedium2, widgetMedium3, widgetMedium4]
        if Set(medium).count != medium.count {
            widgetConfigAlertMessage = "中号组件的四个按钮不能重复，请调整后再保存。"
            showWidgetConfigDuplicateAlert = true
            return
        }

        let ok = WidgetQuickRecordStore.savePreferences(
            small: small,
            medium: medium,
            actionOrder: actionCandidateOrder,
            actionEnabledCount: actionCandidateEnabledCount
        )
        if ok {
            WidgetCenter.shared.reloadAllTimelines()
            exportMessage = "小组件触发设置已保存"
        } else {
            widgetConfigAlertMessage = "保存失败，请重试。"
            showWidgetConfigDuplicateAlert = true
        }
    }

    private func saveSetting() {
        do {
            try modelContext.save()
        } catch {
            exportMessage = "设置保存失败：\(error.localizedDescription)"
        }
    }

    private func clearAll() {
        do {
            let logs = try modelContext.fetch(FetchDescriptor<SmokeLog>())
            logs.forEach(modelContext.delete)
            try modelContext.save()
            exportMessage = "已清空所有记录"
        } catch {
            exportMessage = "清空失败：\(error.localizedDescription)"
        }
    }

    private func exportJSON() {
        do {
            let logs = try modelContext.fetch(FetchDescriptor<SmokeLog>()).sorted(by: { $0.createdAt < $1.createdAt })
            let payload = logs.map {
                [
                    "id": $0.id,
                    "created_at": ISO8601DateFormatter().string(from: $0.createdAt),
                    "trigger_primary": $0.triggerPrimary.rawValue,
                    "trigger_secondary": $0.triggerSecondary ?? "",
                    "delayed_10min": $0.delayed10min ? "1" : "0",
                    "minutes_since_last": $0.minutesSinceLast?.description ?? "",
                    "count_in_day": String($0.countInDay),
                    "is_backfill": $0.isBackfill ? "1" : "0"
                ]
            }

            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            let url = documentsURL().appendingPathComponent("smoke-local-export.json")
            try data.write(to: url)
            exportMessage = "JSON 已导出：\(url.lastPathComponent)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        do {
            let logs = try modelContext.fetch(FetchDescriptor<SmokeLog>()).sorted(by: { $0.createdAt < $1.createdAt })
            var lines = ["id,created_at,trigger_primary,trigger_secondary,delayed_10min,minutes_since_last,count_in_day,is_backfill"]
            let iso = ISO8601DateFormatter()
            for l in logs {
                lines.append([
                    l.id,
                    iso.string(from: l.createdAt),
                    l.triggerPrimary.rawValue,
                    csvEscape(l.triggerSecondary ?? ""),
                    l.delayed10min ? "1" : "0",
                    l.minutesSinceLast?.description ?? "",
                    String(l.countInDay),
                    l.isBackfill ? "1" : "0"
                ].joined(separator: ","))
            }
            let url = documentsURL().appendingPathComponent("smoke-local-export.csv")
            try lines.joined(separator: "\n").data(using: .utf8)?.write(to: url)
            exportMessage = "CSV 已导出：\(url.lastPathComponent)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func csvEscape(_ input: String) -> String {
        if input.contains(",") || input.contains("\"") || input.contains("\n") {
            return "\"" + input.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return input
    }
}
