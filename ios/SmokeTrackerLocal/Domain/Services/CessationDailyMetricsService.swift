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
        let quotaEval = evaluateCategoryQuota(goal: goal)

        if goal.dailyLimit == 0 {
            if smokedCount > 0 {
                lines.append("🔴 出现红色事件；计划继续，下一次冲动回到 0 支计划。")
            }
        } else if smokedCount > goal.dailyLimit {
            lines.append("🔴 今日总量超出目标；计划继续，下一次回到当前周目标。")
        }

        if quotaEval.totalHardOver > 0, let top = topHardOverItem(from: quotaEval) {
            let category = categoryDisplayName(top.category)
            lines.append("🟡 \(category)超出训练目标；剩余烟不要再用于这个场景。")
        }

        if quotaEval.bufferUsed > 0, quotaEval.totalHardOver == 0 {
            lines.append("🔵 已使用今日缓冲；今天不要再扩展例外。")
        }

        if let minDelayed10mCount = goal.minDelayed10mCount, delayedCount < minDelayed10mCount {
            let lack = max(0, minDelayed10mCount - delayedCount)
            lines.append("🔵 延迟达标还差 \(lack) 次；下一支先拖 10 分钟。")
        }

        if let minResistedCravings = goal.minResistedCravings,
           cravingResistedCount < minResistedCravings {
            let lack = max(0, minResistedCravings - cravingResistedCount)
            lines.append("🔵 扛过冲动还差 \(lack) 次；下一次先记录，撑 10 分钟。")
        }

        if let goalMinGap = goal.minIntervalMinutes,
           let minGap = minIntervalMinutes,
           minGap < goalMinGap {
            lines.append("🔵 间隔未达标；下一支尽量拉到 \(goalMinGap) 分钟。")
        }

        return lines
    }

    func nightlyReviewLines(goal: CessationWeeklyGoal) -> [String] {
        let quotaEval = evaluateCategoryQuota(goal: goal)

        let totalLine: String = {
            if goal.dailyLimit == 0 {
                if smokedCount == 0 {
                    return "今日：0/0，继续守住归零。"
                }
                return "今日：\(smokedCount)/0，红色事件；计划继续。"
            }

            if smokedCount > goal.dailyLimit {
                return "今日：\(smokedCount)/\(goal.dailyLimit)，超出目标；计划继续。"
            }
            return "今日：\(smokedCount)/\(goal.dailyLimit)。"
        }()

        let categoryTrainingLine: String = {
            if quotaEval.totalHardOver > 0, let top = topHardOverItem(from: quotaEval) {
                let category = categoryDisplayName(top.category)
                return "分类：\(category)超出 \(top.hardOver)；明天先收这一类。"
            }
            if quotaEval.bufferUsed > 0 {
                return "分类：用了缓冲 \(quotaEval.bufferUsed)/\(quotaEval.bufferTotal)，整体可控。"
            }
            return "分类：控制良好。"
        }()

        let bufferLine: String = {
            if quotaEval.bufferUsed > 0 {
                return "缓冲：已用 \(quotaEval.bufferUsed)/\(quotaEval.bufferTotal)；不结转、不补抽。"
            }
            return "缓冲：未使用；不结转、不补抽。"
        }()

        let behaviorLine: String = {
            var parts: [String] = []
            if let minDelayed10mCount = goal.minDelayed10mCount {
                parts.append("延迟 \(delayedCount)/\(minDelayed10mCount)")
            }
            if let minResistedCravings = goal.minResistedCravings {
                parts.append("扛过冲动 \(cravingResistedCount)/\(minResistedCravings)")
            }
            if parts.isEmpty {
                return "保护：本周不设该项。"
            }
            return "保护：" + parts.joined(separator: "，")
        }()

        let nextFocusLineText: String = {
            if goal.dailyLimit == 0 {
                if smokedCount == 0 {
                    return "明天：继续守住 0 支；冲动先记录，尽量扛过。"
                }
                return "明天：冲动来了先记录，回到 0 支计划。"
            }

            if let top = topHardOverItem(from: quotaEval) {
                return composeNextFocusLine(for: top.category, reason: .hardOver)
            }
            if quotaEval.bufferUsed > 0, let buffered = topBufferUsedItem(from: quotaEval) {
                return composeNextFocusLine(for: buffered.category, reason: .bufferUsed)
            }
            if let next = nextFocusCategory(goal: goal) {
                return composeNextFocusLine(for: next.category, reason: next.reason)
            }
            return "明天：保持节奏，冲动先记录再决定。"
        }()

        return [totalLine, categoryTrainingLine, bufferLine, behaviorLine, nextFocusLineText]
    }

    private func categoryDisplayName(_ category: TriggerPrimary) -> String {
        switch category {
        case .afterWaking:
            return "起床后"
        case .afterMeal:
            return "饭后"
        case .workTransition:
            return "工作转换"
        case .idleTime:
            return "无聊/空档"
        default:
            return category.zhLabel
        }
    }

    private func topHardOverItem(from eval: CategoryQuotaEvaluation) -> CategoryQuotaEvaluationItem? {
        eval.items
            .filter { $0.hardOver > 0 }
            .sorted {
                if $0.hardOver != $1.hardOver { return $0.hardOver > $1.hardOver }
                return categoryPriority($0.category) < categoryPriority($1.category)
            }
            .first
    }

    private enum NextFocusReason {
        case hardOver
        case bufferUsed
        case normal
    }

    private struct NextFocusChoice {
        let category: TriggerPrimary
        let reason: NextFocusReason
    }

    private func topBufferUsedItem(from eval: CategoryQuotaEvaluation) -> CategoryQuotaEvaluationItem? {
        eval.items
            .filter { $0.bufferUsed > 0 }
            .sorted {
                if $0.bufferUsed != $1.bufferUsed { return $0.bufferUsed > $1.bufferUsed }
                return categoryPriority($0.category) < categoryPriority($1.category)
            }
            .first
    }

    private func nextFocusCategory(goal: CessationWeeklyGoal) -> NextFocusChoice? {
        // Normal-day focus should prioritize training-value scenarios:
        // idleTime / workTransition first. Avoid selecting afterWaking as "priority cut"
        // when it is only at/under quota.
        let idleUsed = idleCount
        let idleQuota = goal.categoryQuota.idleTime
        let workUsed = workTransitionCount
        let workQuota = goal.categoryQuota.workTransition

        let idleHas = idleUsed > 0
        let workHas = workUsed > 0

        if idleHas && workHas {
            let idleRatio = idleQuota > 0 ? Double(idleUsed) / Double(idleQuota) : 0
            let workRatio = workQuota > 0 ? Double(workUsed) / Double(workQuota) : 0
            if abs(idleRatio - workRatio) <= 0.10 {
                return .init(category: .idleTime, reason: .normal)
            }
            return idleRatio >= workRatio
                ? .init(category: .idleTime, reason: .normal)
                : .init(category: .workTransition, reason: .normal)
        }

        if idleHas { return .init(category: .idleTime, reason: .normal) }
        if workHas { return .init(category: .workTransition, reason: .normal) }

        if afterMealCount > 0 {
            return .init(category: .afterMeal, reason: .normal)
        }

        if afterWakingCount > 0 {
            return .init(category: .afterWaking, reason: .normal)
        }

        return nil
    }

    private func composeNextFocusLine(for category: TriggerPrimary, reason: NextFocusReason) -> String {
        let name = categoryDisplayName(category)
        switch category {
        case .idleTime:
            return "明天：优先压住\(name)；先记录冲动，拖 10 分钟再决定。"
        case .workTransition:
            return "明天：工作转换先记录冲动，拖 10 分钟再决定。"
        case .afterMeal:
            if reason == .bufferUsed {
                return "明天：饭后已用到缓冲；先拖 10 分钟再决定。"
            }
            return "明天：饭后先拖 10 分钟，再决定。"
        case .afterWaking:
            switch reason {
            case .hardOver:
                return "明天：起床后先守住 1 支上限，不要扩展到第 2 支。"
            case .bufferUsed:
                return "明天：起床后已用到缓冲；先守住 1 支，不要扩展。"
            case .normal:
                return "明天：先守住起床后不超过 1 支，重点放在无聊/工作转换。"
            }
        default:
            return "明天：冲动先记录再决定是否抽。"
        }
    }

    private func categoryPriority(_ category: TriggerPrimary) -> Int {
        switch category {
        case .idleTime:
            return 0
        case .workTransition:
            return 1
        case .afterMeal:
            return 2
        case .afterWaking:
            return 3
        default:
            return 99
        }
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
