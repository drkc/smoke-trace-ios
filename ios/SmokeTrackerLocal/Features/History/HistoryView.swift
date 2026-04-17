import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
    @State private var selectedTrendDate: Date?
    @State private var selectedRollingDate: Date?

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
            Chart {
                ForEach(viewModel.payload.dayCounts) { point in
                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("数量", point.count)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(.blue)

                    if let ma = movingAverageValue(at: point.date, source: viewModel.payload.dayCounts, window: 7) {
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("7日均线", ma)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }

                if let selectedDate = selectedTrendDate,
                   let selectedPoint = nearestPoint(to: selectedDate, in: viewModel.payload.dayCounts) {
                    RuleMark(x: .value("选中日期", selectedPoint.date))
                        .foregroundStyle(.gray.opacity(0.35))
                    PointMark(
                        x: .value("选中日期", selectedPoint.date),
                        y: .value("数量", selectedPoint.count)
                    )
                    .symbolSize(70)
                    .foregroundStyle(.blue)
                    .annotation(position: .top, alignment: .leading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                            Text("数量：\(selectedPoint.count)")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedTrendDate = date
                                    }
                                }
                                .onEnded { _ in
                                    // 保留最后选中点，形成“可左右拖动查看”的体验
                                }
                        )
                }
            }
            .frame(height: 190)

            HStack(spacing: 12) {
                Label("实际", systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Label("7日均线", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

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
            Chart {
                ForEach(viewModel.payload.rolling14DayCounts) { point in
                    BarMark(
                        x: .value("日期", point.date),
                        y: .value("数量", point.count)
                    )
                    .foregroundStyle(.blue.opacity(0.35))

                    if let ma = movingAverageValue(at: point.date, source: viewModel.payload.rolling14DayCounts, window: 7) {
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("7日均线", ma)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }

                if let selectedDate = selectedRollingDate,
                   let selectedPoint = nearestPoint(to: selectedDate, in: viewModel.payload.rolling14DayCounts) {
                    RuleMark(x: .value("选中日期", selectedPoint.date))
                        .foregroundStyle(.gray.opacity(0.35))
                    PointMark(
                        x: .value("选中日期", selectedPoint.date),
                        y: .value("数量", selectedPoint.count)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                            Text("数量：\(selectedPoint.count)")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedRollingDate = date
                                    }
                                }
                                .onEnded { _ in
                                    // 保留最后选中点
                                }
                        )
                }
            }
            .frame(height: 190)

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
            HStack {
                Text("时段热力图（周 × 小时）").font(.headline)
                Spacer()
                Text("总样本：\(viewModel.payload.heatmapCells.map(\.count).reduce(0,+))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(viewModel.payload.heatmapCells) { cell in
                RectangleMark(
                    x: .value("小时", cell.hour),
                    y: .value("星期", cell.weekday)
                )
                .cornerRadius(2)
                .foregroundStyle(heatColor(count: cell.count, maxCount: maxCount))
            }
            .chartYScale(domain: 1...7)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5, 6, 7]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    AxisTick()
                    if let day = value.as(Int.self) {
                        AxisValueLabel(weekdayLabel(day))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23])
            }
            .frame(height: 230)

            VStack(alignment: .leading, spacing: 6) {
                Text("强度图例")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatColor(level: level))
                            .frame(width: 24, height: 10)
                    }
                    Text("低 → 高")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

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

    private func movingAverageValue(at date: Date, source: [DayCountPoint], window: Int) -> Double? {
        guard window > 1 else { return nil }
        let sorted = source.sorted(by: { $0.date < $1.date })
        guard let idx = sorted.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let start = max(0, idx - window + 1)
        let slice = sorted[start...idx]
        let avg = Double(slice.map(\.count).reduce(0, +)) / Double(slice.count)
        return (avg * 10).rounded() / 10
    }

    private func nearestPoint(to target: Date, in points: [DayCountPoint]) -> DayCountPoint? {
        points.min { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }
    }

    private func heatColor(count: Int, maxCount: Int) -> Color {
        let level = maxCount == 0 ? 0 : Double(count) / Double(maxCount)
        return heatColor(level: level)
    }

    private func heatColor(level: Double) -> Color {
        let clamped = min(max(level, 0), 1)
        if clamped < 0.2 { return Color.blue.opacity(0.10) }
        if clamped < 0.4 { return Color.cyan.opacity(0.30) }
        if clamped < 0.6 { return Color.green.opacity(0.45) }
        if clamped < 0.8 { return Color.orange.opacity(0.65) }
        return Color.red.opacity(0.82)
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
