import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showImport = false
    @State private var exportMessage: String?
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
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
            .confirmationDialog("确认清空所有记录？", isPresented: $showClearConfirm) {
                Button("确认清空", role: .destructive) {
                    clearAll()
                }
                Button("取消", role: .cancel) {}
            }
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
