import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    let refreshSignal: UUID
    private let summaryRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    cessationCard
                    nightlyReviewCard

                    AppCard {
                        HStack {
                            Text("先记录：准备抽一支")
                                .font(.headline)
                            Spacer()
                            Text("第一步")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TriggerGrid { trigger in
                            viewModel.prepareCraving(trigger: trigger)
                        }
                    }

                    AppCard {
                        HStack {
                            Text("再确认：抽了")
                                .font(.headline)
                            Spacer()
                            Text("第二步")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("待确认：\(viewModel.pendingCravingText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("确认抽了") {
                            viewModel.confirmSmokedNow()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(!viewModel.canConfirmSmoked)
                    }

                    if let feedback = viewModel.feedback {
                        FeedbackCard(feedback: feedback)
                    }
                }
                .padding()
            }
            .navigationTitle("记录")
            .onAppear {
                viewModel.refreshSummary()
            }
            .onReceive(summaryRefreshTimer) { _ in
                viewModel.refreshSummary()
            }
            .onChange(of: refreshSignal) { _, _ in
                viewModel.refreshSummary()
            }
        }
    }

    private var cessationCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日戒烟看板（\(viewModel.activeWeekLabel)目标）")
                    .font(.headline)

                Text("总支数：\(viewModel.dailyMetrics.smokedCount)/\(viewModel.goalSmokedCount)")
                    .font(.subheadline)
                Text("idle_time：\(viewModel.dailyMetrics.idleCount)/\(viewModel.goalIdleCount)  |  work_transition：\(viewModel.dailyMetrics.workTransitionCount)/\(viewModel.goalWorkTransitionCount)")
                    .font(.subheadline)
                Text("拖延≥10分钟：\(viewModel.dailyMetrics.delayedCount)/\(viewModel.goalDelayedCount)")
                    .font(.subheadline)
                Text("最短间隔：\(minIntervalText)（目标 ≥\(viewModel.goalMinIntervalMinutes) 分钟）")
                    .font(.subheadline)
                Text("起意→抽烟转化率：\(viewModel.dailyMetrics.cravingConversionRateText)（起意\(viewModel.dailyMetrics.cravingCount)，扛过\(viewModel.dailyMetrics.cravingResistedCount)）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !viewModel.warningLines.isEmpty {
                    Divider()
                    ForEach(viewModel.warningLines, id: \.self) { line in
                        Text("⚠️ \(line)")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var nightlyReviewCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("每晚30秒复盘")
                    .font(.headline)
                ForEach(viewModel.nightlyReviewLines, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                }
            }
        }
    }

    private var minIntervalText: String {
        guard let min = viewModel.dailyMetrics.minIntervalMinutes else { return "-" }
        return "\(min) 分钟"
    }

    private var summaryCard: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日已抽")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(viewModel.todayCountText)
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                    Text("距上一根: \(viewModel.sinceLastText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
