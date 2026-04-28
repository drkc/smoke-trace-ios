import SwiftUI
import SwiftData

struct DataManagementSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImport = false
    @State private var exportMessage: String?
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section("数据迁移") {
                Button("导入 Worker 导出 JSON") {
                    showImport = true
                }
            }

            Section("导出") {
                Button("导出 JSON（兼容格式）到 Documents") {
                    exportJSONCompatible()
                }
                Button("导出 JSON（AI 分析 v2）到 Documents") {
                    exportJSONForAI()
                }
                Button("导出 CSV 到 Documents") {
                    exportCSV()
                }
                if let exportMessage {
                    AppHintText(text: exportMessage)
                }
            }

            Section("危险操作") {
                Button("清空所有记录", role: .destructive) {
                    showClearConfirm = true
                }
            }
        }
        .navigationTitle("数据管理")
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

    private func exportJSONCompatible() {
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
            let url = documentsURL().appendingPathComponent("smoke-local-export.compat.json")
            try data.write(to: url)
            exportMessage = "兼容 JSON 已导出：\(url.lastPathComponent)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func exportJSONForAI() {
        do {
            let logs = try modelContext.fetch(FetchDescriptor<SmokeLog>()).sorted(by: { $0.createdAt < $1.createdAt })
            let cravings = try modelContext.fetch(FetchDescriptor<CravingEvent>()).sorted(by: { $0.createdAt < $1.createdAt })
            let setting = AppSetting.fetchOrCreate(in: modelContext)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let payload: [String: Any] = [
                "schema_version": "2.0",
                "exported_at": iso.string(from: Date()),
                "timezone": setting.timezoneIdentifier,
                "source": "SmokeTrackerLocal iOS",
                "logs": logs.map { log in
                    var row: [String: Any] = [
                        "id": log.id,
                        "created_at": iso.string(from: log.createdAt),
                        "trigger_primary": log.triggerPrimary.rawValue,
                        "delayed_10min": log.delayed10min,
                        "count_in_day": log.countInDay,
                        "is_backfill": log.isBackfill
                    ]
                    if let triggerSecondary = log.triggerSecondary, !triggerSecondary.isEmpty {
                        row["trigger_secondary"] = triggerSecondary
                    }
                    if let minutesSinceLast = log.minutesSinceLast {
                        row["minutes_since_last"] = minutesSinceLast
                    }
                    if let insightType = log.insightTypeRaw {
                        row["insight_type"] = insightType
                    }
                    if let insightPrimaryTrigger = log.insightPrimaryTriggerRaw {
                        row["insight_primary_trigger"] = insightPrimaryTrigger
                    }
                    if let insightAction = log.insightAction {
                        row["insight_action"] = insightAction
                    }
                    if let insightError = log.insightError {
                        row["insight_error"] = insightError
                    }
                    return row
                },
                "cravings": cravings.map { event in
                    var row: [String: Any] = [
                        "id": event.id,
                        "created_at": iso.string(from: event.createdAt),
                        "trigger_primary": event.triggerPrimary.rawValue,
                        "status": event.status.rawValue
                    ]
                    if let triggerSecondary = event.triggerSecondary, !triggerSecondary.isEmpty {
                        row["trigger_secondary"] = triggerSecondary
                    }
                    if let resolvedAt = event.resolvedAt {
                        row["resolved_at"] = iso.string(from: resolvedAt)
                    }
                    if let linkedSmokeLogID = event.linkedSmokeLogID {
                        row["linked_smoke_log_id"] = linkedSmokeLogID
                    }
                    return row
                }
            ]

            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let url = documentsURL().appendingPathComponent("smoke-local-export.ai-v2.json")
            try data.write(to: url)
            exportMessage = "AI JSON v2 已导出：\(url.lastPathComponent)"
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
