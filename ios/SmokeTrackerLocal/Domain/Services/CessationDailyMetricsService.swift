import Foundation

struct CessationWeeklyGoal {
    let weekNumber: Int
    let maxSmokedCount: Int
    let maxIdleCount: Int
    let maxWorkTransitionCount: Int
    let minDelayedCount: Int
    let minIntervalMinutes: Int

    static let sixWeekPlan: [CessationWeeklyGoal] = [
        .init(weekNumber: 1, maxSmokedCount: 14, maxIdleCount: 7, maxWorkTransitionCount: 5, minDelayedCount: 3, minIntervalMinutes: 60),
        .init(weekNumber: 2, maxSmokedCount: 12, maxIdleCount: 6, maxWorkTransitionCount: 4, minDelayedCount: 4, minIntervalMinutes: 70),
        .init(weekNumber: 3, maxSmokedCount: 10, maxIdleCount: 5, maxWorkTransitionCount: 3, minDelayedCount: 5, minIntervalMinutes: 90),
        .init(weekNumber: 4, maxSmokedCount: 8, maxIdleCount: 4, maxWorkTransitionCount: 2, minDelayedCount: 6, minIntervalMinutes: 120),
        .init(weekNumber: 5, maxSmokedCount: 5, maxIdleCount: 2, maxWorkTransitionCount: 1, minDelayedCount: 6, minIntervalMinutes: 150),
        .init(weekNumber: 6, maxSmokedCount: 0, maxIdleCount: 0, maxWorkTransitionCount: 0, minDelayedCount: 0, minIntervalMinutes: 180),
    ]

    static var week1Default: CessationWeeklyGoal { sixWeekPlan[0] }
}

struct CessationGoalResolver {
    let timeZone: TimeZone

    func resolveGoal(for date: Date, planStartDate: Date?) -> CessationWeeklyGoal {
        guard let planStartDate else { return .week1Default }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startDay = calendar.startOfDay(for: planStartDate)
        let currentDay = calendar.startOfDay(for: date)
        let dayDiff = calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0
        let weekOffset = max(0, dayDiff / 7)
        let index = min(weekOffset, CessationWeeklyGoal.sixWeekPlan.count - 1)
        return CessationWeeklyGoal.sixWeekPlan[index]
    }
}

struct CessationDailyMetrics {
    let smokedCount: Int
    let idleCount: Int
    let workTransitionCount: Int
    let delayedCount: Int
    let minIntervalMinutes: Int?
    let cravingCount: Int
    let cravingSmokedCount: Int
    let cravingResistedCount: Int

    var cravingConversionRateText: String {
        guard cravingCount > 0 else { return "-" }
        let pct = Int((Double(cravingSmokedCount) / Double(cravingCount)) * 100)
        return "\(pct)%"
    }

    func warningLines(goal: CessationWeeklyGoal) -> [String] {
        var lines: [String] = []
        if smokedCount >= goal.maxSmokedCount {
            lines.append("总支数已到上限（\(smokedCount)/\(goal.maxSmokedCount)）")
        } else if smokedCount >= max(1, goal.maxSmokedCount - 2) {
            lines.append("总支数接近上限（\(smokedCount)/\(goal.maxSmokedCount)）")
        }

        if idleCount >= goal.maxIdleCount {
            lines.append("idle_time 已到上限（\(idleCount)/\(goal.maxIdleCount)）")
        }

        if workTransitionCount >= goal.maxWorkTransitionCount {
            lines.append("work_transition 已到上限（\(workTransitionCount)/\(goal.maxWorkTransitionCount)）")
        }

        if delayedCount < goal.minDelayedCount {
            lines.append("拖延次数偏少（\(delayedCount)/\(goal.minDelayedCount)）")
        }

        if let minGap = minIntervalMinutes, minGap < goal.minIntervalMinutes {
            lines.append("最短间隔偏短（\(minGap)min < \(goal.minIntervalMinutes)min）")
        }

        return lines
    }

    func nightlyReviewLines(goal: CessationWeeklyGoal) -> [String] {
        let totalLine = "今天总数：\(smokedCount)/\(goal.maxSmokedCount)"
        let exceedLine = smokedCount > goal.maxSmokedCount
            ? "是否超标：是（超 \(smokedCount - goal.maxSmokedCount)）"
            : "是否超标：否"

        let triggerLine: String = {
            if idleCount == 0 && workTransitionCount == 0 {
                return "最多的 trigger：无"
            }
            if idleCount >= workTransitionCount {
                return "最多的 trigger：idle_time（\(idleCount)）"
            }
            return "最多的 trigger：work_transition（\(workTransitionCount)）"
        }()

        let delayedLine = "今天成功延迟（≥10min）：\(delayedCount)"

        let dangerLine: String = {
            if idleCount >= workTransitionCount && idleCount > 0 {
                return "明天最危险场景：空档时刻（规则：idle 先延迟10分钟）"
            }
            if workTransitionCount > 0 {
                return "明天最危险场景：任务切换后（规则：每2次切换最多1支）"
            }
            return "明天最危险场景：晚间时段（规则：22:30后不抽）"
        }()

        return [totalLine, exceedLine, triggerLine, delayedLine, dangerLine]
    }
}

struct CessationDailyMetricsService {
    let timeZone: TimeZone

    func build(for date: Date, logs: [SmokeLog], cravings: [CravingEvent]) -> CessationDailyMetrics {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        let dayLogs = logs
            .filter { $0.createdAt >= start && $0.createdAt < end }
            .sorted(by: { $0.createdAt < $1.createdAt })

        let smokedCount = dayLogs.count
        let idleCount = dayLogs.filter { $0.triggerPrimary == .idleTime }.count
        let workCount = dayLogs.filter { $0.triggerPrimary == .workTransition }.count
        let delayedCount = dayLogs.filter { $0.delayed10min }.count

        var minInterval: Int?
        if dayLogs.count >= 2 {
            for i in 1..<dayLogs.count {
                let gap = Int(dayLogs[i].createdAt.timeIntervalSince(dayLogs[i - 1].createdAt) / 60)
                if gap >= 0 {
                    minInterval = minInterval.map { min($0, gap) } ?? gap
                }
            }
        }

        let dayCravings = cravings.filter { $0.createdAt >= start && $0.createdAt < end }
        let cravingCount = dayCravings.count
        let smokedCravingCount = dayCravings.filter { $0.status == .smoked }.count
        let resistedCravingCount = dayCravings.filter { $0.status == .resisted }.count

        return CessationDailyMetrics(
            smokedCount: smokedCount,
            idleCount: idleCount,
            workTransitionCount: workCount,
            delayedCount: delayedCount,
            minIntervalMinutes: minInterval,
            cravingCount: cravingCount,
            cravingSmokedCount: smokedCravingCount,
            cravingResistedCount: resistedCravingCount
        )
    }
}
