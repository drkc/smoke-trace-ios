import SwiftUI

struct PinSetupView: View {
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("设置 PIN") {
                    SecureField("输入 4-8 位 PIN", text: $pin)
                        .keyboardType(.numberPad)
                    SecureField("再次输入 PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        submit()
                    }
                }
            }
        }
    }

    private func submit() {
        guard pin == confirmPin else {
            message = "两次输入不一致"
            return
        }

        guard (4...8).contains(pin.count) else {
            message = "PIN 需为 4-8 位"
            return
        }

        guard pin.allSatisfy({ $0.isNumber }) else {
            message = "PIN 仅支持数字"
            return
        }

        onSave(pin)
        dismiss()
    }
}
