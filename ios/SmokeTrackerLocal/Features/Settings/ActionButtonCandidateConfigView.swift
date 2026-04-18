import SwiftUI
import WidgetKit

struct ActionButtonCandidateConfigView: View {
    @Binding var order: [String]
    @Binding var enabledCount: Int
    let labelForRaw: (String) -> String

    @State private var saveMessage = ""
    @State private var showSaveAlert = false

    private var clampedEnabledCount: Int {
        min(max(enabledCount, 1), max(order.count, 1))
    }

    var body: some View {
        List {
            Section {
                Picker("显示数量", selection: $enabledCount) {
                    ForEach(1...8, id: \.self) { count in
                        Text("\(count) 项").tag(count)
                    }
                }

                Text("拖动排序后，分割线以上会作为 Action Button 每次弹出的候选项；分割线以下隐藏。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("待选列表设置")
            }

            Section {
                ForEach(Array(order.enumerated()), id: \.element) { index, raw in
                    VStack(alignment: .leading, spacing: 8) {
                        if index == clampedEnabledCount {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .foregroundStyle(.secondary)
                                Text("以下隐藏")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        HStack {
                            Text(labelForRaw(raw))
                            Spacer()
                            Text(index < clampedEnabledCount ? "可选" : "隐藏")
                                .font(.caption)
                                .foregroundStyle(index < clampedEnabledCount ? .green : .secondary)
                        }
                    }
                }
                .onMove(perform: move)
            } header: {
                Text("顺序（可拖动）")
            }
        }
        .navigationTitle("Action Button 待选")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    saveActionCandidates()
                }
            }
            EditButton()
        }
        .onChange(of: enabledCount) { _, newValue in
            let maxCount = max(order.count, 1)
            enabledCount = min(max(newValue, 1), maxCount)
        }
        .alert("待选列表设置", isPresented: $showSaveAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(saveMessage)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }

    private func saveActionCandidates() {
        enabledCount = clampedEnabledCount
        let ok = WidgetQuickRecordStore.saveActionButtonConfig(order: order, enabledCount: enabledCount)
        if ok {
            WidgetCenter.shared.reloadAllTimelines()
            saveMessage = "Action Button 待选列表已保存"
        } else {
            saveMessage = "保存失败，请重试"
        }
        showSaveAlert = true
    }
}
