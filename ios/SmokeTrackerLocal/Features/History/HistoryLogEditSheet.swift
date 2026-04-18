import SwiftUI

struct HistoryLogEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var createdAt: Date
    @State private var trigger: TriggerPrimary
    @State private var triggerSecondary: String
    @State private var delayed10min: Bool

    let onSave: (EditableHistoryLog) -> Void
    let onDelete: (String) -> Void

    private let logID: String

    init(draft: EditableHistoryLog, onSave: @escaping (EditableHistoryLog) -> Void, onDelete: @escaping (String) -> Void) {
        self._createdAt = State(initialValue: draft.createdAt)
        self._trigger = State(initialValue: draft.trigger)
        self._triggerSecondary = State(initialValue: draft.triggerSecondary)
        self._delayed10min = State(initialValue: draft.delayed10min)
        self.logID = draft.id
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("记录信息") {
                    DatePicker("发生时间", selection: $createdAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    Picker("触发原因", selection: $trigger) {
                        ForEach(TriggerPrimary.allCases) { item in
                            Text(item.zhLabel).tag(item)
                        }
                    }
                    TextField("补充说明（可选）", text: $triggerSecondary)
                    Toggle("这根当时有先拖10分钟", isOn: $delayed10min)
                }

                Section {
                    Button("删除这条记录", role: .destructive) {
                        onDelete(logID)
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            EditableHistoryLog(
                                id: logID,
                                createdAt: createdAt,
                                trigger: trigger,
                                triggerSecondary: triggerSecondary,
                                delayed10min: delayed10min
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
