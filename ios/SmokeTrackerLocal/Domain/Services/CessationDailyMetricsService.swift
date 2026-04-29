import Foundation

struct CessationCategoryQuota {
    let afterWaking: Int
    let workTransition: Int
    let idleTime: Int
    let afterMeal: Int
    let buffer: Int
}

enum CategoryQuotaEvaluationStatus {
    case ok
    case bufferUsed
    case over
}

struct CategoryQuotaEvaluationItem {
    let category: TriggerPrimary
    let used: Int
    let quota: Int
    let over: Int
    let bufferUsed: Int
    let hardOver: Int
    let status: CategoryQuotaEvaluationStatus
}

struct CategoryQuotaEvaluation {
    let items: [CategoryQuotaEvaluationItem]
    let bufferTotal: Int
    let bufferUsed: Int
    let bufferRemaining: Int
    let totalOver: Int
    let totalHardOver: Int
    let hasHardOver: Bool
    // Semantics:
    // - hardOver / totalHardOver are training-signal metrics only.
    // - They do NOT terminate the plan, invalidate the day, reset planStartDate,
    //   rollback week number, or restart the program.
}

struct CessationWeeklyGoal {
    let weekNumber: Int
    let dailyLimit: Int
    let categoryQuota: CessationCategoryQuota
    let minDelayed10mCount: Int?
    let minResistedCravings: Int?
    let minIntervalMinutes: Int?

    // Compatibility shim for old UI bindings. Remove after UI fully migrates to v2 goal fields.
    var maxSmokedCount: Int { dailyLimit }
    var maxIdleCount: Int { categoryQuota.idleTime }
    var maxWorkTransitionCount: Int { categoryQuota.workTransition }
    var minDelayedCount: Int { minDelayed10mCount ?? 0 }

    static let sixWeekPlan: [CessationWeeklyGoal] = [
        .init(
            weekNumber: 1,
            dailyLimit: 14,
            categoryQuota: .init(afterWaking: 1, workTransition: 5, idleTime: 6, afterMeal: 1, buffer: 1),
            minDelayed10mCount: 3,
            minResistedCravings: 1,
            minIntervalMinutes: 60
        ),
        .init(
            weekNumber: 2,
            dailyLimit: 12,
            categoryQuota: .init(afterWaking: 1, workTransition: 4, idleTime: 5, afterMeal: 1, buffer: 1),
            minDelayed10mCount: 4,
            minResistedCravings: 2,
            minIntervalMinutes: 70
        ),
        .init(
            weekNumber: 3,
            dailyLimit: 10,
            categoryQuota: .init(afterWaking: 1, workTransition: 3, idleTime: 4, afterMeal: 1, buffer: 1),
            minDelayed10mCount: 5,
            minResistedCravings: 2,
            minIntervalMinutes: 90
        ),
        .init(
            weekNumber: 4,
            dailyLimit: 8,
            categoryQuota: .init(afterWaking: 1, workTransition: 2, idleTime: 3, afterMeal: 1, buffer: 1),
            minDelayed10mCount: 6,
            minResistedCravings: 3,
            minIntervalMinutes: 120
        ),
        .init(
            weekNumber: 5,
            dailyLimit: 6,
            categoryQuota: .init(afterWaking: 1, workTransition: 1, idleTime: 2, afterMeal: 1, buffer: 1),
            minDelayed10mCount: 6,
            minResistedCravings: 3,
            minIntervalMinutes: 150
        ),
        .init(
            weekNumber: 6,
            dailyLimit: 0,
            categoryQuota: .init(afterWaking: 0, workTransition: 0, idleTime: 0, afterMeal: 0, buffer: 0),
            minDelayed10mCount: nil,
            minResistedCravings: 3,
            minIntervalMinutes: nil
        ),
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
    let afterWakingCount: Int
    let afterMealCount: Int

    init(
        smokedCount: Int,
        idleCount: Int,
        workTransitionCount: Int,
        delayedCount: Int,
        minIntervalMinutes: Int?,
        cravingCount: Int,
        cravingSmokedCount: Int,
        cravingResistedCount: Int,
        afterWakingCount: Int = 0,
        afterMealCount: Int = 0
    ) {
        self.smokedCount = smokedCount
        self.idleCount = idleCount
        self.workTransitionCount = workTransitionCount
        self.delayedCount = delayedCount
        self.minIntervalMinutes = minIntervalMinutes
        self.cravingCount = cravingCount
        self.cravingSmokedCount = cravingSmokedCount
        self.cravingResistedCount = cravingResistedCount
        self.afterWakingCount = afterWakingCount
        self.afterMealCount = afterMealCount
    }

    var cravingConversionRateText: String {
        guard cravingCount > 0 else { return "-" }
        let pct = Int((Double(cravingSmokedCount) / Double(cravingCount)) * 100)
        return "\(pct)%"
    }

    func evaluateCategoryQuota(goal: CessationWeeklyGoal) -> CategoryQuotaEvaluation {
        // Stable allocation order for buffer interpretation (deterministic):
        // 1) afterWaking, 2) afterMeal, 3) workTransition, 4) idleTime
        // This order only affects which category is marked as bufferUsed vs hardOver;
        // it does NOT change dailyLimit counting.
        let categoryUsage: [(TriggerPrimary, Int, Int)] = [
            (.afterWaking, afterWakingCount, goal.categoryQuota.afterWaking),
            (.afterMeal, afterMealCount, goal.categoryQuota.afterMeal),
            (.workTransition, workTransitionCount, goal.categoryQuota.workTransition),
            (.idleTime, idleCount, goal.categoryQuota.idleTime),
        ]

        var remainingBuffer = max(0, goal.categoryQuota.buffer)
        var items: [CategoryQuotaEvaluationItem] = []

        for (category, used, quota) in categoryUsage {
            let over = max(0, used - quota)
            let consumed = min(over, remainingBuffer)
            remainingBuffer -= consumed
            let hardOver = over - consumed

            let status: CategoryQuotaEvaluationStatus = {
                if hardOver > 0 { return .over }
                if consumed > 0 { return .bufferUsed }
                return .ok
            }()

            items.append(
                CategoryQuotaEvaluationItem(
                    category: category,
                    used: used,
                    quota: quota,
                    over: over,
                    bufferUsed: consumed,
                    hardOver: hardOver,
                    status: status
                )
            )
        }

        let totalBuffer = max(0, goal.categoryQuota.buffer)
        let usedBuffer = totalBuffer - remainingBuffer
        let totalOver = items.reduce(0) { $0 + $1.over }
        let totalHardOver = max(0, totalOver - totalBuffer)

        return CategoryQuotaEvaluation(
            items: items,
            bufferTotal: totalBuffer,
            bufferUsed: usedBuffer,
            bufferRemaining: remainingBuffer,
            totalOver: totalOver,
            totalHardOver: totalHardOver,
            hasHardOver: totalHardOver > 0
        )
    }

    func warningLines(goal: CessationWeeklyGoal) -> [String] {
        var lines: [String] = []

        if goal.dailyLimit == 0 {
            if smokedCount > 0 {
                lines.append("Quit周出现抽烟记录（\(smokedCount)/0）：这是红色事件，但计划继续；下一次 craving 请回到 0 支计划。")
            }
        } else if smokedCount >= goal.dailyLimit {
            lines.append("总支数已到上限（\(smokedCount)/\(goal.dailyLimit)）")
        } else if smokedCount >= max(1, goal.dailyLimit - 2) {
            lines.append("总支数接近上限（\(smokedCount)/\(goal.dailyLimit)）")
        }

        // Compatibility warning lines for current UI (idle/work). Full quota UI integration will follow.
        if idleCount >= goal.maxIdleCount {
            lines.append("idle_time 已到上限（\(idleCount)/\(goal.maxIdleCount)）")
        }

        if workTransitionCount >= goal.maxWorkTransitionCount {
            lines.append("work_transition 已到上限（\(workTransitionCount)/\(goal.maxWorkTransitionCount)）")
        }

        if let minDelayed10mCount = goal.minDelayed10mCount, delayedCount < minDelayed10mCount {
            lines.append("拖延次数偏少（\(delayedCount)/\(minDelayed10mCount)）")
        }

        if let goalMinGap = goal.minIntervalMinutes,
           let minGap = minIntervalMinutes,
           minGap < goalMinGap {
            lines.append("最短间隔偏短（\(minGap)min < \(goalMinGap)min）")
        }

        if let minResistedCravings = goal.minResistedCravings,
           cravingResistedCount < minResistedCravings {
            lines.append("扛过次数偏少（\(cravingResistedCount)/\(minResistedCravings)）")
        }

        return lines
    }

    func nightlyReviewLines(goal: CessationWeeklyGoal) -> [String] {
        let totalLine = "今天总数：\(smokedCount)/\(goal.dailyLimit)"
        let exceedLine = smokedCount > goal.dailyLimit
            ? "是否超标：是（超 \(smokedCount - goal.dailyLimit)）"
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

        let delayedLine: String = {
            if goal.minDelayed10mCount == nil { return "今天成功延迟（≥10min）：N/A（Quit周）" }
            return "今天成功延迟（≥10min）：\(delayedCount)"
        }()

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
        let afterWakingCount = dayLogs.filter { $0.triggerPrimary == .afterWaking }.count
        let afterMealCount = dayLogs.filter { $0.triggerPrimary == .afterMeal }.count
        let delayedCount = dayLogs.filter { $0.delayed10min }.count

        // NOTE: triggers outside the configured category quota (e.g. driving/stress/other)
        // are intentionally counted only in dailyLimit for this round. They do not consume
        // category quota nor buffer yet; UI integration can decide how to surface them later.

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
            cravingResistedCount: resistedCravingCount,
            afterWakingCount: afterWakingCount,
            afterMealCount: afterMealCount
        )
    }
}
