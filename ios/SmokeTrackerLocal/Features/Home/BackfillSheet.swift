import SwiftUI

struct BackfillSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSubmit: (TriggerPrimary, Date, String?, Bool) -> Void

    @State private var createdAt: Date = Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date()
    @State private var trigger: TriggerPrimary = .other
    @State private var secondary: String = ""
    @State private var delayed10min: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("补记") {
                    DatePicker("发生时间", selection: $createdAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    Picker("触发原因", selection: $trigger) {
                        ForEach(TriggerPrimary.allCases) { item in
                            Text(item.zhLabel).tag(item)
                        }
                    }
                    TextField("补充说明（可选）", text: $secondary)
                    Toggle("这根当时有先拖10分钟", isOn: $delayed10min)
                }
            }
            .navigationTitle("补记一根")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSubmit(trigger, createdAt, secondary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : secondary, delayed10min)
                        dismiss()
                    }
                }
            }
        }
    }
}
