import SwiftUI

struct HistoryCravingEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var createdAt: Date
    @State private var trigger: TriggerPrimary
    @State private var triggerSecondary: String
    @State private var status: CravingEventStatus
    @State private var showDeleteConfirm = false

    let onSave: (EditableHistoryCraving) -> Void
    let onDelete: (String) -> Void

    private let cravingID: String

    init(draft: EditableHistoryCraving, onSave: @escaping (EditableHistoryCraving) -> Void, onDelete: @escaping (String) -> Void) {
        self._createdAt = State(initialValue: draft.createdAt)
        self._trigger = State(initialValue: draft.trigger)
        self._triggerSecondary = State(initialValue: draft.triggerSecondary)
        self._status = State(initialValue: draft.status)
        self.cravingID = draft.id
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("起意信息") {
                    DatePicker("发生时间", selection: $createdAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    Picker("触发原因", selection: $trigger) {
                        ForEach(TriggerPrimary.allCases) { item in
                            Text(item.zhLabel).tag(item)
                        }
                    }
                    TextField("补充说明（可选）", text: $triggerSecondary)
                    Picker("状态", selection: $status) {
                        Text("待确认").tag(CravingEventStatus.pending)
                        Text("已抽").tag(CravingEventStatus.smoked)
                        Text("已扛过").tag(CravingEventStatus.resisted)
                    }
                }

                Section {
                    Button("删除这条起意", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("编辑起意")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            EditableHistoryCraving(
                                id: cravingID,
                                createdAt: createdAt,
                                trigger: trigger,
                                triggerSecondary: triggerSecondary,
                                status: status
                            )
                        )
                        dismiss()
                    }
                }
            }
            .confirmationDialog("确认删除这条起意？", isPresented: $showDeleteConfirm) {
                Button("确认删除", role: .destructive) {
                    onDelete(cravingID)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
