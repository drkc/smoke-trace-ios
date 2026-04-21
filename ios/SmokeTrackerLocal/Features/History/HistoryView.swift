import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
    let refreshSignal: UUID
    @State private var selectedTrendDate: Date?
    @State private var selectedRollingDate: Date?
    @State private var editingDraft: EditableHistoryLog?
    @State private var operationErrorMessage: String?
    @State private var pendingDeleteLogID: String?

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
                        syncSelectionToLatest()
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
            .sheet(item: $editingDraft) { draft in
                HistoryLogEditSheet(
                    draft: draft,
                    onSave: { newDraft in
                        operationErrorMessage = viewModel.saveEditedLog(newDraft)
                    },
                    onDelete: { id in
                        pendingDeleteLogID = id
                    }
                )
            }
            .confirmationDialog("确认删除这条记录？", isPresented: Binding(
                get: { pendingDeleteLogID != nil },
                set: { shown in if !shown { pendingDeleteLogID = nil } }
            )) {
                Button("确认删除", role: .destructive) {
                    if let id = pendingDeleteLogID {
                        operationErrorMessage = viewModel.deleteLog(id: id)
                    }
                    pendingDeleteLogID = nil
                    editingDraft = nil
                }
                Button("取消", role: .cancel) {
                    pendingDeleteLogID = nil
                }
            }
            .alert("操作失败", isPresented: Binding(
                get: { operationErrorMessage != nil },
                set: { shown in if !shown { operationErrorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {
                    operationErrorMessage = nil
                }
            } message: {
                Text(operationErrorMessage ?? "未知错误")
            }
            .onAppear {
                viewModel.reload()
                syncSelectionToLatest()
            }
            .onChange(of: refreshSignal) { _, _ in
                viewModel.reload()
                syncSelectionToLatest()
            }
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
        let selectedPoint = nearestPoint(to: selectedTrendDate ?? Date.distantPast, in: viewModel.payload.dayCounts)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("趋势（当前区间）").font(.headline)
                Spacer()
                if let selectedPoint {
                    trendTag(date: selectedPoint.date, count: selectedPoint.count)
                }
            }

            Chart {
                ForEach(viewModel.payload.dayCounts) { point in
                    BarMark(
                        x: .value("日期", point.date),
                        y: .value("数量", point.count)
                    )
                    .foregroundStyle(.blue.opacity(0.35))

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

                if let selectedPoint {
                    RuleMark(x: .value("选中日期", selectedPoint.date))
                        .foregroundStyle(.gray.opacity(0.35))
                    PointMark(
                        x: .value("选中日期", selectedPoint.date),
                        y: .value("数量", selectedPoint.count)
                    )
                    .symbolSize(80)
                    .foregroundStyle(.blue)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedTrendDate = date
                                    }
                                }
                        )
                }
            }
            .onAppear {
                if selectedTrendDate == nil {
                    selectedTrendDate = viewModel.payload.dayCounts.last?.date
                }
            }
            .frame(height: 190)

            HStack(spacing: 12) {
                Label("柱状", systemImage: "chart.bar")
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
        let selectedPoint = nearestPoint(to: selectedRollingDate ?? Date.distantPast, in: viewModel.payload.rolling14DayCounts)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("近14天趋势").font(.headline)
                Spacer()
                if let selectedPoint {
                    trendTag(date: selectedPoint.date, count: selectedPoint.count)
                }
            }

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

                if let selectedPoint {
                    RuleMark(x: .value("选中日期", selectedPoint.date))
                        .foregroundStyle(.gray.opacity(0.35))
                    PointMark(
                        x: .value("选中日期", selectedPoint.date),
                        y: .value("数量", selectedPoint.count)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(80)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedRollingDate = date
                                    }
                                }
                        )
                }
            }
            .onAppear {
                if selectedRollingDate == nil {
                    selectedRollingDate = viewModel.payload.rolling14DayCounts.last?.date
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

    @ViewBuilder
    private func trendTag(date: Date, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
            Text("\(count)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.25), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        if clamped < 0.2 { return Color.blue.opacity(0.12) }
        if clamped < 0.4 { return Color.teal.opacity(0.35) }
        if clamped < 0.6 { return Color.indigo.opacity(0.52) }
        if clamped < 0.8 { return Color.purple.opacity(0.68) }
        return Color.pink.opacity(0.84)
    }

    private func syncSelectionToLatest() {
        selectedTrendDate = viewModel.payload.dayCounts.last?.date
        selectedRollingDate = viewModel.payload.rolling14DayCounts.last?.date
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Text("\(item.trigger.zhLabel) · 间隔 \(item.minutesSinceLast?.description ?? "-") 分钟")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("编辑") {
                                editingDraft = viewModel.loadEditableLog(id: item.id)
                            }
                            .buttonStyle(.bordered)

                            Button("删除", role: .destructive) {
                                pendingDeleteLogID = item.id
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.caption)
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
