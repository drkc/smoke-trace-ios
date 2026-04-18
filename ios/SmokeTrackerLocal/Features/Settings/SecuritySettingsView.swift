import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSetting]

    @State private var pinEnabledToggle = false
    @State private var biometricsToggle = false
    @State private var showPinSetup = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("应用锁") {
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

            if let message {
                Section {
                    AppHintText(text: message)
                }
            }
        }
        .navigationTitle("安全与隐私")
        .sheet(isPresented: $showPinSetup) {
            PinSetupView(title: pinEnabledToggle ? "修改 PIN" : "设置 PIN") { newPin in
                savePIN(newPin)
            }
        }
        .onAppear {
            _ = AppSetting.fetchOrCreate(in: modelContext)
            syncState()
        }
        .onChange(of: settings.count) { _, _ in
            syncState()
        }
    }

    private var setting: AppSetting {
        settings.first ?? AppSetting.fetchOrCreate(in: modelContext)
    }

    private func syncState() {
        pinEnabledToggle = setting.pinEnabled
        biometricsToggle = setting.pinEnabled && setting.biometricsEnabled
    }

    private func setPinEnabled(_ enabled: Bool) {
        if enabled {
            showPinSetup = true
            return
        }

        setting.pinEnabled = false
        setting.biometricsEnabled = false
        saveSetting()
        syncState()
    }

    private func setBiometricsEnabled(_ enabled: Bool) {
        guard pinEnabledToggle else {
            biometricsToggle = false
            return
        }

        if !enabled {
            setting.biometricsEnabled = false
            saveSetting()
            syncState()
            return
        }

        guard AppLockService.canEvaluateBiometrics() else {
            message = "当前设备不可用生物识别"
            biometricsToggle = false
            return
        }

        Task {
            let ok = await AppLockService.authenticateWithBiometrics(reason: "启用生物识别解锁")
            await MainActor.run {
                if ok {
                    setting.biometricsEnabled = true
                    saveSetting()
                    syncState()
                    message = ""
                } else {
                    message = "生物识别验证未通过，未启用"
                    biometricsToggle = false
                }
            }
        }
    }

    private func savePIN(_ pin: String) {
        setting.pinHash = AppLockService.hashPIN(pin)
        setting.pinEnabled = true
        saveSetting()
        syncState()
        message = "PIN 已保存"
    }

    private func saveSetting() {
        do {
            try modelContext.save()
        } catch {
            message = "设置保存失败：\(error.localizedDescription)"
        }
    }
}
