import Foundation
import SwiftData

enum HistoryRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var zhLabel: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        }
    }
}

struct ComparePreviousSummary {
    let currentTotal: Int
    let previousTotal: Int
    let deltaTotal: Int
    let deltaTotalPct: Double?

    let currentDailyAverage: Double
    let previousDailyAverage: Double
    let deltaDailyAverage: Double
}

struct HistorySummary {
    let total: Int
    let averageInterval: Int?
    let shortestInterval: Int?
    let longestInterval: Int?
    let dominantTrigger: TriggerPrimary?
    let dailyAverage: Double
    let comparePrevious: ComparePreviousSummary
}

struct DayCountPoint: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

struct TriggerCountPoint: Identifiable {
    let trigger: TriggerPrimary
    let count: Int
    var id: String { trigger.rawValue }
}

struct HistoryLogItem: Identifiable {
    let id: String
    let createdAt: Date
    let trigger: TriggerPrimary
    let minutesSinceLast: Int?
}

struct HistoryPayload {
    let summary: HistorySummary
    let dayCounts: [DayCountPoint]
    let triggerCounts: [TriggerCountPoint]
    let details: [HistoryLogItem]
}

private struct RangeInterval {
    let start: Date
    let end: Date
    let dayCount: Int
}

private struct StatsSnapshot {
    let total: Int
    let averageInterval: Int?
    let shortestInterval: Int?
    let longestInterval: Int?
    let dominantTrigger: TriggerPrimary?
    let dailyAverage: Double
}

struct HistoryAggregationService {
    let timeZone: TimeZone

    func buildPayload(range: HistoryRange, anchor: Date, logs: [SmokeLog]) -> HistoryPayload {
        let currentInterval = resolveInterval(range: range, anchor: anchor)
        let previousInterval = resolvePreviousInterval(range: range, current: currentInterval)

        let currentLogs = logsIn(interval: currentInterval, logs: logs)
        let previousLogs = logsIn(interval: previousInterval, logs: logs)

        let currentStats = makeStats(logs: currentLogs, dayCount: currentInterval.dayCount)
        let previousStats = makeStats(logs: previousLogs, dayCount: previousInterval.dayCount)

        let compare = ComparePreviousSummary(
            currentTotal: currentStats.total,
            previousTotal: previousStats.total,
            deltaTotal: currentStats.total - previousStats.total,
            deltaTotalPct: pctDelta(current: currentStats.total, previous: previousStats.total),
            currentDailyAverage: currentStats.dailyAverage,
            previousDailyAverage: previousStats.dailyAverage,
            deltaDailyAverage: round1(currentStats.dailyAverage - previousStats.dailyAverage)
        )

        let summary = HistorySummary(
            total: currentStats.total,
            averageInterval: currentStats.averageInterval,
            shortestInterval: currentStats.shortestInterval,
            longestInterval: currentStats.longestInterval,
            dominantTrigger: currentStats.dominantTrigger,
            dailyAverage: currentStats.dailyAverage,
            comparePrevious: compare
        )

        let dayBuckets = Dictionary(grouping: currentLogs) { dayStart(for: $0.createdAt) }
            .map { DayCountPoint(date: $0.key, count: $0.value.count) }
            .sorted(by: { $0.date < $1.date })

        let triggerMap = Dictionary(grouping: currentLogs, by: { $0.triggerPrimary }).mapValues(\.count)
        let triggerCounts = triggerMap
            .map { TriggerCountPoint(trigger: $0.key, count: $0.value) }
            .sorted(by: { $0.count > $1.count })

        let details = currentLogs
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { HistoryLogItem(id: $0.id, createdAt: $0.createdAt, trigger: $0.triggerPrimary, minutesSinceLast: $0.minutesSinceLast) }

        return HistoryPayload(summary: summary, dayCounts: dayBuckets, triggerCounts: triggerCounts, details: details)
    }

    private func makeStats(logs: [SmokeLog], dayCount: Int) -> StatsSnapshot {
        let intervals = logs.compactMap(\.minutesSinceLast)
        let triggerMap = Dictionary(grouping: logs, by: { $0.triggerPrimary }).mapValues(\.count)
        let dominantTrigger = triggerMap.max(by: { $0.value < $1.value })?.key
        let dailyAverage = round1(Double(logs.count) / Double(max(1, dayCount)))

        return StatsSnapshot(
            total: logs.count,
            averageInterval: intervals.isEmpty ? nil : Int(Double(intervals.reduce(0, +)) / Double(intervals.count)),
            shortestInterval: intervals.min(),
            longestInterval: intervals.max(),
            dominantTrigger: dominantTrigger,
            dailyAverage: dailyAverage
        )
    }

    private func logsIn(interval: RangeInterval, logs: [SmokeLog]) -> [SmokeLog] {
        logs.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
    }

    private func resolveInterval(range: HistoryRange, anchor: Date) -> RangeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: anchor)

        switch range {
        case .day:
            let end = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            return RangeInterval(start: dayStart, end: end, dayCount: 1)
        case .week:
            let weekday = calendar.component(.weekday, from: dayStart)
            let mondayOffset = (weekday + 5) % 7
            let weekStart = calendar.date(byAdding: .day, value: -mondayOffset, to: dayStart)!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return RangeInterval(start: weekStart, end: weekEnd, dayCount: 7)
        case .month:
            let comp = calendar.dateComponents([.year, .month], from: dayStart)
            let monthStart = calendar.date(from: comp)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let days = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            return RangeInterval(start: monthStart, end: monthEnd, dayCount: days)
        }
    }

    private func resolvePreviousInterval(range: HistoryRange, current: RangeInterval) -> RangeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        switch range {
        case .day:
            let start = calendar.date(byAdding: .day, value: -1, to: current.start)!
            return RangeInterval(start: start, end: current.start, dayCount: 1)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: current.start)!
            return RangeInterval(start: start, end: current.start, dayCount: 7)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: current.start)!
            let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            return RangeInterval(start: start, end: current.start, dayCount: days)
        }
    }

    private func dayStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    private func pctDelta(current: Int, previous: Int) -> Double? {
        guard previous > 0 else { return nil }
        return round1((Double(current - previous) / Double(previous)) * 100)
    }

    private func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
