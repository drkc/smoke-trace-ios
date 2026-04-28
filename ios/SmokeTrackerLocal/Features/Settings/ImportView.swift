import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var isError = false
    @State private var report: WorkerJsonImporter.ReconciliationReport?

    var body: some View {
        Form {
            Section("导入") {
                Text("支持导入 Worker 兼容 JSON 与 AI 分析 v2 JSON 文件。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("选择并导入 JSON") {
                    showImporter = true
                }
                .buttonStyle(.borderedProminent)

                if let importMessage {
                    Text(importMessage)
                        .foregroundStyle(isError ? .red : .green)
                        .font(.footnote)
                }
            }

            if let report {
                Section("导入对账总览") {
                    LabeledContent("源数据总数", value: "\(report.sourceTotal)")
                    LabeledContent("本地导入前", value: "\(report.localBeforeTotal)")
                    LabeledContent("本地导入后", value: "\(report.localAfterTotal)")
                    LabeledContent("重复跳过", value: "\(report.duplicateCount)")
                    LabeledContent("非法触发跳过", value: "\(report.invalidTriggerCount)")
                    if let dr = report.sourceDateRange {
                        LabeledContent("源数据起始", value: dr.start.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("源数据结束", value: dr.end.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section("导入对账（按触发类型）") {
                    ForEach(report.triggerRows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.trigger.zhLabel)
                                .font(.subheadline)
                            Text("源: \(row.sourceCount)  导入新增: \(row.importedCount)  本地净增: \(row.localDelta)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("导入数据")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else { return }
            let data = try readImportedData(from: fileURL)
            let importer = WorkerJsonImporter(timeZone: .current)
            let output = try importer.importFromWorkerJSON(data: data, context: modelContext)
            isError = false
            importMessage = "导入完成：日志新增 \(output.inserted) 条，日志跳过 \(output.skipped) 条；起意新增 \(output.cravingsInserted) 条，起意跳过 \(output.cravingsSkipped) 条"
            report = output.report
        } catch {
            isError = true
            if let importError = error as? WorkerImportError {
                importMessage = "导入失败：\(importError.localizedDescription)"
            } else if let decodingError = error as? DecodingError {
                importMessage = "导入失败：JSON 字段格式不匹配（\(describeDecodingError(decodingError))）"
            } else {
                importMessage = "导入失败：\(error.localizedDescription)"
            }
            report = nil
        }
    }

    private func readImportedData(from fileURL: URL) throws -> Data {
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: fileURL)
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            if path.isEmpty {
                return context.debugDescription
            }
            return "\(path)：\(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
