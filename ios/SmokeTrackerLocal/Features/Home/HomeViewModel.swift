import Foundation
import SwiftData

enum PaceCompare {
    case higher
    case similar
    case lower
}

struct HomeFeedback {
    let title: String
    let detail: String
    let tip: String?
    let latestLogID: String?
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var feedback: HomeFeedback?
    @Published var todayCountText: String = "-"
    @Published var sinceLastText: String = "-"
    @Published var pendingCravingText: String = "无"
    @Published var canConfirmSmoked: Bool = false
    @Published var dailyMetrics = CessationDailyMetrics(
        smokedCount: 0,
        idleCount: 0,
        workTransitionCount: 0,
        delayedCount: 0,
        minIntervalMinutes: nil,
        cravingCount: 0,
        cravingSmokedCount: 0,
        cravingResistedCount: 0,
        stressCount: 0,
        drivingCount: 0,
        socialCount: 0,
        otherCount: 0
    )
    @Published var warningLines: [String] = []
    @Published var nightlyReviewLines: [String] = []
    @Published var activeWeekLabel: String = "第1周"

    var goalSmokedCount: Int { activeGoal.maxSmokedCount }
    var goalIdleCount: Int { activeGoal.maxIdleCount }
    var goalWorkTransitionCount: Int { activeGoal.maxWorkTransitionCount }
    var goalDelayedCount: Int { activeGoal.minDelayedCount }
    var goalMinIntervalMinutes: Int { activeGoal.minIntervalMinutes ?? 0 }
    var hasDelayedGoal: Bool { activeGoal.minDelayed10mCount != nil }
    var hasIntervalGoal: Bool { activeGoal.minIntervalMinutes != nil }

    var actionStatusText: String {
        let smoked = dailyMetrics.smokedCount
        let limit = activeGoal.dailyLimit

        if limit == 0 {
            if smoked == 0 { return "继续守住归零。" }
            return "出现红色事件；计划继续。"
        }

        if smoked > limit { return "已超出；计划继续。" }
        if Double(smoked) >= Double(limit) * 0.8 { return "接近上限。" }
        return "节奏安全。"
    }

    var actionNextStepText: String {
        let quota = dailyMetrics.evaluateCategoryQuota(goal: activeGoal)
        let risk = dailyMetrics.evaluateRiskTriggers(goal: activeGoal)

        if activeGoal.dailyLimit == 0 {
            if let topRisk = risk.topRiskTrigger {
                return "\(categoryName(topRisk))冲动先记录，回到 0 支。"
            }
            return "冲动来了先记录，撑 10 分钟。"
        }

        if dailyMetrics.smokedCount > activeGoal.dailyLimit {
            return "先回到当前周目标，不再补抽。"
        }

        if quota.totalHardOver > 0,
           let top = quota.items.filter({ $0.hardOver > 0 }).max(by: { $0.hardOver < $1.hardOver }) {
            return "剩余烟不要用于\(categoryName(top.category))。"
        }

        if risk.isRiskTriggerElevated, let topRisk = risk.topRiskTrigger {
            return riskActionHint(topRisk)
        }

        if risk.hasRiskTrigger, let topRisk = risk.topRiskTrigger {
            return riskActionHint(topRisk)
        }

        if quota.bufferUsed > 0,
           quota.totalHardOver == 0,
           let topBuffer = quota.items.filter({ $0.bufferUsed > 0 }).max(by: { $0.bufferUsed < $1.bufferUsed }) {
            if topBuffer.category == .afterWaking {
                return "起床后先守住 1 支上限。"
            }
            return "今天不要再扩展例外。"
        }

        let idleRatio = ratio(used: dailyMetrics.idleCount, quota: goalIdleCount)
        let workRatio = ratio(used: dailyMetrics.workTransitionCount, quota: goalWorkTransitionCount)

        if idleRatio >= workRatio, dailyMetrics.idleCount > 0 {
            return "无聊/空档：先离开空档，拖 10 分钟。"
        }
        if dailyMetrics.workTransitionCount > 0 {
            return "工作转换：先记录冲动，拖 10 分钟。"
        }
        return "先记录冲动，拖 10 分钟。"
    }

    var actionBufferText: String {
        let quota = dailyMetrics.evaluateCategoryQuota(goal: activeGoal)
        if quota.totalHardOver > 0 {
            return "缓冲：已用完，别再扩展例外。"
        }
        if quota.bufferUsed > 0 {
            return "缓冲：\(quota.bufferRemaining)/\(quota.bufferTotal) 已使用。"
        }
        return "缓冲：\(quota.bufferRemaining)/\(quota.bufferTotal) 可用。"
    }

    var actionExtraHintText: String? {
        let quota = dailyMetrics.evaluateCategoryQuota(goal: activeGoal)
        if quota.bufferUsed > 0, quota.totalHardOver == 0 {
            return "今天不要再扩展例外。"
        }
        return nil
    }

    var goalDetailSummaryText: String {
        let quota = dailyMetrics.evaluateCategoryQuota(goal: activeGoal)
        if let top = quota.items.filter({ $0.hardOver > 0 }).max(by: { $0.hardOver < $1.hardOver }) {
            return "总量 \(dailyMetrics.smokedCount)/\(goalSmokedCount) · \(categoryName(top.category))超出 +\(top.hardOver)"
        }
        if quota.bufferUsed > 0 {
            return "总量 \(dailyMetrics.smokedCount)/\(goalSmokedCount) · 缓冲已用"
        }
        return "总量 \(dailyMetrics.smokedCount)/\(goalSmokedCount) · 缓冲 \(quota.bufferRemaining)/\(quota.bufferTotal)"
    }

    var nightlyReviewSummaryText: String {
        let quota = dailyMetrics.evaluateCategoryQuota(goal: activeGoal)

        if activeGoal.dailyLimit == 0 {
            return dailyMetrics.smokedCount == 0
                ? "守住 0 支；冲动先记录。"
                : "红色事件；下一次回到 0 支。"
        }

        if dailyMetrics.smokedCount > goalSmokedCount {
            return "已超出；下一支回到当前周目标。"
        }
        if Double(dailyMetrics.smokedCount) >= Double(max(1, goalSmokedCount)) * 0.8 {
            if quota.totalHardOver > 0 { return "接近上限；优先收紧分类超出。" }
            return "接近上限；剩余烟避开高风险触发。"
        }
        if quota.bufferUsed > 0 {
            return "缓冲已用；今天别再扩展例外。"
        }
        return "节奏安全；明天按当前策略继续。"
    }

    private var activeGoal = CessationWeeklyGoal.week1Default

    private let context: ModelContext
    private var logWriter: LogWriteService
    private var cravingFlow: CravingFlowService
    private var suggestionEngineEnabled: Bool = true
    private var planStartDate: Date?

    init(context: ModelContext, setting: AppSetting? = nil) {
        self.context = context
        let resolvedSetting = setting ?? AppSetting()
        self.logWriter = LogWriteService(timeZone: HomeViewModel.resolveTimeZone(from: resolvedSetting.timezoneIdentifier))
        self.cravingFlow = CravingFlowService(logWriter: logWriter)
        self.suggestionEngineEnabled = resolvedSetting.suggestionEngineEnabled

        if let setting {
            if let existing = setting.cessationPlanStartDate {
                self.planStartDate = existing
            } else {
                setting.cessationPlanStartDate = Date()
                try? context.save()
                self.planStartDate = setting.cessationPlanStartDate
            }
        } else {
            self.planStartDate = Date()
        }

        refreshSummary()
    }

    func apply(setting: AppSetting) {
        logWriter = LogWriteService(timeZone: Self.resolveTimeZone(from: setting.timezoneIdentifier))
        cravingFlow = CravingFlowService(logWriter: logWriter)
        suggestionEngineEnabled = setting.suggestionEngineEnabled

        if let existing = setting.cessationPlanStartDate {
            planStartDate = existing
        } else {
            setting.cessationPlanStartDate = Date()
            try? context.save()
            planStartDate = setting.cessationPlanStartDate
        }

        refreshSummary()
    }

    func refreshSummary() {
        let logs = fetchAllLogs()
        todayCountText = String(StatsService.countInDay(for: Date(), logs: logs, timeZone: logWriter.timeZone))
        sinceLastText = formatSinceLastText(minutes: StatsService.minutesFromNow(to: logs.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt))

        let cravings = fetchAllCravings()
        dailyMetrics = CessationDailyMetricsService(timeZone: logWriter.timeZone)
            .build(for: Date(), logs: logs, cravings: cravings)

        activeGoal = CessationGoalResolver(timeZone: logWriter.timeZone)
            .resolveGoal(for: Date(), planStartDate: planStartDate)
        activeWeekLabel = "第\(activeGoal.weekNumber)周"

        warningLines = dailyMetrics.warningLines(goal: activeGoal)
        nightlyReviewLines = dailyMetrics.nightlyReviewLines(goal: activeGoal)

        if let pending = cravingFlow.latestPending(in: context) {
            canConfirmSmoked = true
            pendingCravingText = "\(pending.triggerPrimary.zhLabel)（\(formatSinceNow(from: pending.createdAt))）"
        } else {
            canConfirmSmoked = false
            pendingCravingText = "无"
        }
    }

    func prepareCraving(trigger: TriggerPrimary) {
        do {
            let event = try cravingFlow.createPendingCraving(in: context, trigger: trigger)
            feedback = HomeFeedback(
                title: "已记录准备抽",
                detail: "\(event.triggerPrimary.zhLabel)（\(formatTime(event.createdAt))）",
                tip: "先拖10分钟，再决定要不要抽",
                latestLogID: nil
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "保存失败",
                detail: error.localizedDescription,
                tip: nil,
                latestLogID: nil
            )
        }
    }

    func confirmSmokedNow() {
        do {
            guard let result = try cravingFlow.confirmSmokedNearestPending(in: context) else {
                feedback = HomeFeedback(
                    title: "暂无待确认",
                    detail: "请先点一次“准备抽一支”",
                    tip: nil,
                    latestLogID: nil
                )
                return
            }

            let pace = calcVsYesterdaySoFar(logs: fetchAllLogs(), at: result.log.createdAt)
            let tip = suggestionEngineEnabled ? TipPool.nextTip(
                trigger: result.log.triggerPrimary,
                minutesSinceLast: result.log.minutesSinceLast,
                countInDay: result.log.countInDay,
                delayed10min: result.log.delayed10min,
                vsYesterdaySoFar: pace
            ) : nil

            let delayText = result.delayedEffective ? "已拖延≥10分钟" : "未达到10分钟"
            feedback = HomeFeedback(
                title: "已确认抽了",
                detail: "\(result.log.triggerPrimary.zhLabel)（今日第 \(result.log.countInDay) 根，\(delayText)）",
                tip: tip,
                latestLogID: result.log.id
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "确认失败",
                detail: error.localizedDescription,
                tip: nil,
                latestLogID: nil
            )
        }
    }

    func cancelPendingCraving() {
        do {
            guard let event = try cravingFlow.cancelNearestPending(in: context) else {
                feedback = HomeFeedback(
                    title: "暂无待取消",
                    detail: "当前没有预备状态",
                    tip: nil,
                    latestLogID: nil
                )
                return
            }

            feedback = HomeFeedback(
                title: "已取消",
                detail: "\(event.triggerPrimary.zhLabel) 本次已记为扛过",
                tip: "不错，继续保持",
                latestLogID: nil
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "取消失败",
                detail: error.localizedDescription,
                tip: nil,
                latestLogID: nil
            )
        }
    }

    private func calcVsYesterdaySoFar(logs: [SmokeLog], at current: Date) -> PaceCompare {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = logWriter.timeZone

        let todayStart = calendar.startOfDay(for: current)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let yesterdaySameTime = calendar.date(byAdding: .day, value: -1, to: current)!

        let todaySoFar = logs.filter { $0.createdAt >= todayStart && $0.createdAt <= current }.count
        let yesterdaySoFar = logs.filter { $0.createdAt >= yesterdayStart && $0.createdAt <= yesterdaySameTime }.count

        let maxTotal = max(todaySoFar, yesterdaySoFar)
        let diff = todaySoFar - yesterdaySoFar

        if maxTotal >= 4 && diff >= 2 { return .higher }
        if maxTotal >= 4 && diff <= -2 { return .lower }
        return .similar
    }

    private func fetchAllLogs() -> [SmokeLog] {
        (try? context.fetch(FetchDescriptor<SmokeLog>())) ?? []
    }

    private func fetchAllCravings() -> [CravingEvent] {
        (try? context.fetch(FetchDescriptor<CravingEvent>())) ?? []
    }

    private static func resolveTimeZone(from identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }

    private func categoryName(_ trigger: TriggerPrimary) -> String {
        switch trigger {
        case .idleTime: return "无聊/空档"
        case .workTransition: return "工作转换"
        case .afterMeal: return "饭后"
        case .afterWaking: return "起床后"
        default: return trigger.zhLabel
        }
    }

    private func riskActionHint(_ trigger: TriggerPrimary) -> String {
        switch trigger {
        case .stress:
            return "压力：先记录冲动，拖 10 分钟。"
        case .driving:
            return "开车：先设定不抽，停车后再记录。"
        case .social:
            return "社交：先把烟放远，冲动先记录。"
        case .other:
            return "其他触发：先记录原因，不直接补抽。"
        default:
            return "冲动先记录，拖 10 分钟。"
        }
    }

    private func ratio(used: Int, quota: Int) -> Double {
        guard quota > 0 else { return 0 }
        return Double(used) / Double(quota)
    }

    private func formatSinceLastText(minutes: Int?) -> String {
        guard let minutes else { return "-" }
        if minutes <= 0 { return "刚刚" }
        if minutes < 60 { return "\(minutes) 分钟" }

        let hours = minutes / 60
        let remain = minutes % 60
        if remain == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(remain) 分钟"
    }

    private func formatSinceNow(from date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes)分钟前" }
        let hours = minutes / 60
        let remain = minutes % 60
        if remain == 0 { return "\(hours)小时前" }
        return "\(hours)小时\(remain)分钟前"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
