import SwiftUI

struct SettingsView: View {
    @State private var actionModeLabel = ActionButtonExecutionMode.systemChooser.zhLabel
    @State private var actionPositionLabel = ActionButtonPickerPosition.center.zhLabel
    @State private var actionPreview = "-"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        QuickRecordSettingsView()
                    } label: {
                        rowLabel(
                            title: "快捷记录",
                            subtitle: "Widget + Action Button + 待选列表"
                        )
                    }

                    NavigationLink {
                        SecuritySettingsView()
                    } label: {
                        rowLabel(
                            title: "安全与隐私",
                            subtitle: "PIN / Face ID"
                        )
                    }

                    NavigationLink {
                        DataManagementSettingsView()
                    } label: {
                        rowLabel(
                            title: "数据管理",
                            subtitle: "导入 / 导出 / 清空"
                        )
                    }
                } header: {
                    Text("设置分组")
                }

                Section {
                    AppHintText(text: "Action Button 模式：\(actionModeLabel)")
                    AppHintText(text: "拉起面板位置：\(actionPositionLabel)")
                    AppHintText(text: "当前待选：\(actionPreview)")
                } header: {
                    Text("当前生效")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                refreshSummary()
            }
        }
    }

    @ViewBuilder
    private func rowLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func refreshSummary() {
        actionModeLabel = WidgetQuickRecordStore.loadActionButtonExecutionMode().zhLabel
        actionPositionLabel = WidgetQuickRecordStore.loadActionButtonPickerPosition().zhLabel

        let choices = WidgetQuickRecordStore.loadActionButtonChoices()
            .compactMap(TriggerPrimary.init(rawValue:))
            .map(\.zhLabel)
        actionPreview = choices.isEmpty ? "无" : choices.joined(separator: "、")
    }
}
