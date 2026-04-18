import SwiftUI

struct TriggerGrid: View {
    let onTap: (TriggerPrimary) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(TriggerPrimary.allCases) { trigger in
                Button {
                    onTap(trigger)
                } label: {
                    Text(trigger.zhLabel)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
