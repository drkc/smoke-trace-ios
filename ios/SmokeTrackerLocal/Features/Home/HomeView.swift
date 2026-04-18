import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @State private var showBackfill = false
    private let summaryRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summaryCard

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("这根是因为什么？")
                                .font(.headline)
                            Spacer()
                            Text("快捷记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TriggerGrid { trigger in
                            viewModel.quickLog(trigger: trigger)
                        }
                        HStack {
                            Spacer()
                            Button("补记一根") {
                                showBackfill = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let feedback = viewModel.feedback {
                        FeedbackCard(
                            feedback: feedback,
                            onRevert: { viewModel.revertLatest() },
                            onMarkDelayed: { viewModel.markLatestDelayed() }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("记录")
            .sheet(isPresented: $showBackfill) {
                BackfillSheet { trigger, date, secondary, delayed in
                    viewModel.backfill(trigger: trigger, createdAt: date, secondary: secondary, delayed10min: delayed)
                }
            }
            .onAppear {
                viewModel.refreshSummary()
            }
            .onReceive(summaryRefreshTimer) { _ in
                viewModel.refreshSummary()
            }
        }
    }

    private var summaryCard: some View {
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
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
