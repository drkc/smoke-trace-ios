import SwiftUI

struct TriggerGrid: View {
    let onTap: (TriggerPrimary) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(TriggerPrimary.allCases) { trigger in
                Button(trigger.zhLabel) {
                    onTap(trigger)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}
