import SwiftUI

struct FeedbackCard: View {
    let feedback: HomeFeedback

    var body: some View {
        AppCard {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let tip = feedback.tip, !tip.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.green)
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
