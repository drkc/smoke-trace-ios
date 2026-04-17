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
    let canRevert: Bool
    let canMarkDelayed: Bool
    let latestLogID: String?
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var feedback: HomeFeedback?
    @Published var todayCountText: String = "-"
    @Published var sinceLastText: String = "-"

    private let context: ModelContext
    private let logWriter: LogWriteService

    init(context: ModelContext, timeZone: TimeZone = .current) {
        self.context = context
        self.logWriter = LogWriteService(timeZone: timeZone)
        refreshSummary()
    }

    func refreshSummary() {
        let logs = fetchAllLogs()
        todayCountText = String(StatsService.countInDay(for: Date(), logs: logs, timeZone: logWriter.timeZone))
        sinceLastText = StatsService.minutesFromNow(to: logs.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt)
            .map(String.init) ?? "-"
    }

    func quickLog(trigger: TriggerPrimary) {
        do {
            let logs = fetchAllLogs()
            let log = try logWriter.createLog(
                in: context,
                existingLogs: logs,
                trigger: trigger,
                triggerSecondary: nil,
                delayed10min: false,
                createdAt: Date(),
                isBackfill: false
            )

            let pace = calcVsYesterdaySoFar(logs: fetchAllLogs(), at: log.createdAt)
            let tip = TipPool.nextTip(
                trigger: trigger,
                minutesSinceLast: log.minutesSinceLast,
                countInDay: log.countInDay,
                delayed10min: false,
                vsYesterdaySoFar: pace
            )

            feedback = HomeFeedback(
                title: "已记录",
                detail: "\(trigger.zhLabel)（今日第 \(log.countInDay) 根，距上一根 \(log.minutesSinceLast?.description ?? "-") 分钟）",
                tip: tip,
                canRevert: true,
                canMarkDelayed: true,
                latestLogID: log.id
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "保存失败",
                detail: error.localizedDescription,
                tip: nil,
                canRevert: false,
                canMarkDelayed: false,
                latestLogID: nil
            )
        }
    }

    func backfill(trigger: TriggerPrimary, createdAt: Date, secondary: String?, delayed10min: Bool) {
        do {
            if createdAt.timeIntervalSinceNow > 60 {
                feedback = HomeFeedback(
                    title: "补记失败",
                    detail: "补记时间不能晚于当前时间",
                    tip: nil,
                    canRevert: false,
                    canMarkDelayed: false,
                    latestLogID: nil
                )
                return
            }

            let logs = fetchAllLogs()
            let log = try logWriter.createLog(
                in: context,
                existingLogs: logs,
                trigger: trigger,
                triggerSecondary: secondary,
                delayed10min: delayed10min,
                createdAt: createdAt,
                isBackfill: true
            )

            let pace = calcVsYesterdaySoFar(logs: fetchAllLogs(), at: log.createdAt)
            let tip = TipPool.nextTip(
                trigger: trigger,
                minutesSinceLast: log.minutesSinceLast,
                countInDay: log.countInDay,
                delayed10min: delayed10min,
                vsYesterdaySoFar: pace
            )

            feedback = HomeFeedback(
                title: "补记已保存",
                detail: "\(trigger.zhLabel)（当日第 \(log.countInDay) 根，距上一根 \(log.minutesSinceLast?.description ?? "-") 分钟）",
                tip: tip,
                canRevert: true,
                canMarkDelayed: false,
                latestLogID: log.id
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "补记失败",
                detail: error.localizedDescription,
                tip: nil,
                canRevert: false,
                canMarkDelayed: false,
                latestLogID: nil
            )
        }
    }

    func revertLatest() {
        do {
            let ok = try logWriter.revertLatest(in: context, logs: fetchAllLogs())
            feedback = HomeFeedback(
                title: ok ? "已撤销" : "暂无可撤销记录",
                detail: ok ? "已撤销最新记录" : "当前没有记录",
                tip: nil,
                canRevert: false,
                canMarkDelayed: false,
                latestLogID: nil
            )
            refreshSummary()
        } catch {
            feedback = HomeFeedback(
                title: "撤销失败",
                detail: error.localizedDescription,
                tip: nil,
                canRevert: false,
                canMarkDelayed: false,
                latestLogID: nil
            )
        }
    }

    func markLatestDelayed() {
        do {
            let logs = fetchAllLogs().sorted(by: { $0.createdAt > $1.createdAt })
            guard let latest = logs.first else {
                feedback = HomeFeedback(
                    title: "暂无可标记记录",
                    detail: "当前没有记录",
                    tip: nil,
                    canRevert: false,
                    canMarkDelayed: false,
                    latestLogID: nil
                )
                return
            }
            try logWriter.markDelayed(in: context, log: latest)

            let pace = calcVsYesterdaySoFar(logs: fetchAllLogs(), at: Date())
            let tip = TipPool.nextTip(
                trigger: latest.triggerPrimary,
                minutesSinceLast: latest.minutesSinceLast,
                countInDay: latest.countInDay,
                delayed10min: true,
                vsYesterdaySoFar: pace
            )

            feedback = HomeFeedback(
                title: "已标记",
                detail: "这次有先拖10分钟",
                tip: tip,
                canRevert: true,
                canMarkDelayed: false,
                latestLogID: latest.id
            )
        } catch {
            feedback = HomeFeedback(
                title: "更新失败",
                detail: error.localizedDescription,
                tip: nil,
                canRevert: false,
                canMarkDelayed: false,
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
}
