import SwiftUI

struct FeedbackCard: View {
    let feedback: HomeFeedback
    let onRevert: () -> Void
    let onMarkDelayed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(feedback.title)
                .font(.headline)

            Text(feedback.detail)
                .font(.subheadline)

            if let tip = feedback.tip, !tip.isEmpty {
                Text("即时提示：\(tip)")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            HStack {
                if feedback.canRevert {
                    Button("撤销") { onRevert() }
                        .buttonStyle(.bordered)
                }
                if feedback.canMarkDelayed {
                    Button("这次其实有先拖10分钟") { onMarkDelayed() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
