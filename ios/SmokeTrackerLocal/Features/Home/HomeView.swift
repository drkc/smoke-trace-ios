import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    let refreshSignal: UUID
    @State private var showPendingActionDialog = false
    @State private var showGoalDetails = false
    @State private var showNightlyReview = false
    private let summaryRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    summaryCard
                    actionCard

                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("先记录：准备抽一支")
                                    .font(.headline)
                                Spacer()
                                Text("第一步")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            TriggerGrid(buttonHeight: 44, rowSpacing: 8, columnSpacing: 10) { trigger in
                                viewModel.prepareCraving(trigger: trigger)
                            }
                            .controlSize(.small)
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("再确认：抽了")
                                    .font(.headline)
                                Spacer()
                                Text("第二步")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("待确认：\(viewModel.pendingCravingText)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Button("确认/取消") {
                                showPendingActionDialog = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .disabled(!viewModel.canConfirmSmoked)
                        }
                    }

                    if let feedback = viewModel.feedback {
                        FeedbackCard(feedback: feedback)
                    }

                    goalDetailCard
                    nightlyReviewCard
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .navigationTitle("记录")
            .confirmationDialog("处理这次预备状态", isPresented: $showPendingActionDialog) {
                Button("确认抽了", role: .none) {
                    viewModel.confirmSmokedNow()
                }
                Button("取消这次", role: .destructive) {
                    viewModel.cancelPendingCraving()
                }
                Button("返回", role: .cancel) {}
            }
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

    private var goalDetailCard: some View {
        AppCard {
            DisclosureGroup(isExpanded: $showGoalDetails) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("总支数：\(viewModel.dailyMetrics.smokedCount)/\(viewModel.goalSmokedCount)")
                        .font(.subheadline)
                    Text("无聊/空档 \(viewModel.dailyMetrics.idleCount)/\(viewModel.goalIdleCount)｜工作转换 \(viewModel.dailyMetrics.workTransitionCount)/\(viewModel.goalWorkTransitionCount)")
                        .font(.subheadline)
                    if viewModel.hasDelayedGoal {
                        Text("延迟达标：\(viewModel.dailyMetrics.delayedCount)/\(viewModel.goalDelayedCount)")
                            .font(.subheadline)
                    } else {
                        Text("延迟达标：本周不设目标")
                            .font(.subheadline)
                    }
                    if viewModel.hasIntervalGoal {
                        Text("最短间隔：\(minIntervalText)（目标 ≥\(viewModel.goalMinIntervalMinutes) 分钟）")
                            .font(.subheadline)
                    } else {
                        Text("最短间隔：\(minIntervalText)（本周不设间隔目标）")
                            .font(.subheadline)
                    }
                    Text("冲动转化率：\(viewModel.dailyMetrics.cravingConversionRateText)（冲动\(viewModel.dailyMetrics.cravingCount)，扛过\(viewModel.dailyMetrics.cravingResistedCount)）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !viewModel.warningLines.isEmpty {
                        Divider()
                        ForEach(viewModel.warningLines, id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日目标详情（\(viewModel.activeWeekLabel)）")
                        .font(.headline)
                    Text(viewModel.goalDetailSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日行动")
                    .font(.headline)
                Text(viewModel.actionStatusText)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(viewModel.actionNextStepText)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(viewModel.actionBufferText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var nightlyReviewCard: some View {
        AppCard {
            DisclosureGroup(isExpanded: $showNightlyReview) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.nightlyReviewLines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                    }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("每晚30秒复盘")
                        .font(.headline)
                    Text(viewModel.nightlyReviewSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日进度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.dailyMetrics.smokedCount)/\(viewModel.goalSmokedCount)")
                        .font(.system(size: 32, weight: .bold))
                        .monospacedDigit()
                    Text("距上一根：\(viewModel.sinceLastText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
