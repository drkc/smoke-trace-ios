import SwiftUI

struct TriggerGrid: View {
    let onTap: (TriggerPrimary) -> Void
    let buttonHeight: CGFloat
    let rowSpacing: CGFloat
    let columnSpacing: CGFloat

    init(
        buttonHeight: CGFloat = 44,
        rowSpacing: CGFloat = 10,
        columnSpacing: CGFloat = 10,
        onTap: @escaping (TriggerPrimary) -> Void
    ) {
        self.buttonHeight = max(44, buttonHeight)
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
        self.onTap = onTap
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: columnSpacing),
            GridItem(.flexible(), spacing: columnSpacing)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(TriggerPrimary.allCases) { trigger in
                Button {
                    onTap(trigger)
                } label: {
                    Text(trigger.zhLabel)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: buttonHeight)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
