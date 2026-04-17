import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("范围", selection: $viewModel.selectedRange) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.zhLabel).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedRange) { _, _ in
                        viewModel.reload()
                    }

                    summaryCard
                    trendCard
                    rollingTrendCard
                    heatmapCard
                    triggerCard
                    detailCard
                }
                .padding()
            }
            .navigationTitle("历史")
            .onAppear { viewModel.reload() }
        }
    }

    private var summaryCard: some View {
        let s = viewModel.payload.summary
        let c = s.comparePrevious

        return VStack(alignment: .leading, spacing: 8) {
            Text("摘要").font(.headline)
            Text("总数：\(s.total)")
            Text("平均间隔：\(s.averageInterval?.description ?? "-") 分钟")
            Text("最短间隔：\(s.shortestInterval?.description ?? "-") 分钟")
            Text("最长间隔：\(s.longestInterval?.description ?? "-") 分钟")
            Text("最常见触发：\(s.dominantTrigger?.zhLabel ?? "-")")
            Text("区间日均：\(viewModel.dailyAverageText)")
            Text("\(viewModel.compareTitle)：\(viewModel.compareText)")
            Text("上一区间总数：\(c.previousTotal)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("趋势（当前区间）").font(.headline)
            Chart(viewModel.payload.dayCounts) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("数量", point.count)
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)

            if viewModel.payload.summary.total < 6 {
                Text("当前样本较少，趋势仅供参考")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rollingTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近14天趋势").font(.headline)
            Chart(viewModel.payload.rolling14DayCounts) { point in
                BarMark(
                    x: .value("日期", point.date),
                    y: .value("数量", point.count)
                )
            }
            .frame(height: 180)

            Text("固定窗口，不受日/周/月切换影响")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var heatmapCard: some View {
        let maxCount = max(1, viewModel.payload.heatmapCells.map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("时段热力图（周 × 小时）").font(.headline)

            Chart(viewModel.payload.heatmapCells) { cell in
                RectangleMark(
                    x: .value("小时", cell.hour),
                    y: .value("星期", weekdayLabel(cell.weekday))
                )
                .foregroundStyle(
                    .blue.opacity(0.12 + 0.88 * Double(cell.count) / Double(maxCount))
                )
            }
            .chartYScale(domain: ["周一", "周二", "周三", "周四", "周五", "周六", "周日"])
            .frame(height: 220)

            Text("颜色越深表示该时段记录越多")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        default: return "周日"
        }
    }

    private var triggerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("触发分布").font(.headline)
            Chart(viewModel.payload.triggerCounts) { item in
                BarMark(
                    x: .value("触发", item.trigger.zhLabel),
                    y: .value("次数", item.count)
                )
            }
            .frame(height: 220)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("明细").font(.headline)
            if viewModel.payload.details.isEmpty {
                Text("暂无数据").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.payload.details.prefix(50)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Text("\(item.trigger.zhLabel) · 间隔 \(item.minutesSinceLast?.description ?? "-") 分钟")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
