import SwiftUI
import SwiftData

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

    private func syncToggleState() {
        pinEnabledToggle = setting.pinEnabled
        biometricsToggle = setting.pinEnabled && setting.biometricsEnabled
        suggestionEngineToggle = setting.suggestionEngineEnabled
        timezoneSelection = setting.timezoneIdentifier
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
