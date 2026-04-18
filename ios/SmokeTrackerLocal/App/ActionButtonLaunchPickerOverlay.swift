import SwiftUI

struct ActionButtonLaunchPickerOverlay: View {
    let choices: [TriggerPrimary]
    let position: ActionButtonPickerPosition
    let onSelect: (TriggerPrimary) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            overlayStack
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var overlayStack: some View {
        switch position {
        case .top:
            VStack {
                panel
                Spacer(minLength: 0)
            }
        case .center:
            VStack {
                Spacer(minLength: 0)
                panel
                Spacer(minLength: 0)
            }
        case .bottom:
            VStack {
                Spacer(minLength: 0)
                panel
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("请选择触发原因")
                    .font(.headline)
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .font(.subheadline)
            }

            ForEach(choices, id: \.rawValue) { trigger in
                Button {
                    onSelect(trigger)
                } label: {
                    HStack {
                        Text(trigger.zhLabel)
                            .font(.body)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}
