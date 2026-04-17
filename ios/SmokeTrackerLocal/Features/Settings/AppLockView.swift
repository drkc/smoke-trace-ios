import SwiftUI

struct AppLockView: View {
    let setting: AppSetting
    let onUnlocked: () -> Void

    @State private var pinInput = ""
    @State private var message: String?
    @State private var isCheckingBiometrics = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)

                Text("应用已锁定")
                    .font(.title3.weight(.semibold))

                if setting.biometricsEnabled {
                    Button {
                        unlockWithBiometrics()
                    } label: {
                        Label(isCheckingBiometrics ? "验证中..." : "使用生物识别解锁", systemImage: "faceid")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingBiometrics)
                }

                SecureField("输入 PIN", text: $pinInput)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("PIN 解锁") {
                    unlockWithPIN()
                }
                .buttonStyle(.bordered)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(20)
        }
        .onAppear {
            if setting.biometricsEnabled {
                unlockWithBiometrics()
            }
        }
    }

    private func unlockWithPIN() {
        guard let pinHash = setting.pinHash, !pinHash.isEmpty else {
            message = "PIN 未设置，请到设置页重新配置。"
            return
        }

        if AppLockService.verify(pin: pinInput, against: pinHash) {
            pinInput = ""
            message = nil
            onUnlocked()
        } else {
            message = "PIN 不正确"
        }
    }

    private func unlockWithBiometrics() {
        guard !isCheckingBiometrics else { return }
        guard setting.biometricsEnabled else { return }

        isCheckingBiometrics = true
        Task {
            let ok = await AppLockService.authenticateWithBiometrics(reason: "解锁 Smoke Tracker")
            await MainActor.run {
                isCheckingBiometrics = false
                if ok {
                    message = nil
                    onUnlocked()
                } else {
                    message = "生物识别未通过，请使用 PIN 解锁。"
                }
            }
        }
    }
}
