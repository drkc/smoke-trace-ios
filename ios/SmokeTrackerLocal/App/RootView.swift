import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSetting]

    @State private var isUnlocked = true

    var body: some View {
        let setting = effectiveSetting

        ZStack {
            TabView {
                HomeView(viewModel: HomeViewModel(context: modelContext, setting: setting))
                    .id(homeViewIdentity)
                    .tabItem {
                        Label("记录", systemImage: "plus.circle")
                    }

                HistoryView(viewModel: HistoryViewModel(context: modelContext))
                    .tabItem {
                        Label("历史", systemImage: "chart.bar")
                    }

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
            }
            .blur(radius: shouldShowLockGate ? 4 : 0)
            .disabled(shouldShowLockGate)

            if shouldShowLockGate {
                AppLockView(
                    setting: setting,
                    onUnlocked: { isUnlocked = true }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            _ = AppSetting.fetchOrCreate(in: modelContext)
            refreshLockStateForCurrentSetting()
            WidgetQuickRecordProcessor.processPendingRequests(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                if setting.pinEnabled {
                    isUnlocked = false
                }
            case .active:
                refreshLockStateForCurrentSetting()
                WidgetQuickRecordProcessor.processPendingRequests(in: modelContext)
            @unknown default:
                break
            }
        }
        .onChange(of: setting.pinEnabled) { _, enabled in
            if !enabled {
                isUnlocked = true
            }
        }
    }

    private var effectiveSetting: AppSetting {
        settings.first ?? AppSetting.fetchOrCreate(in: modelContext)
    }

    private var homeViewIdentity: String {
        "\(effectiveSetting.timezoneIdentifier)|\(effectiveSetting.suggestionEngineEnabled)"
    }

    private var shouldShowLockGate: Bool {
        effectiveSetting.pinEnabled && !isUnlocked
    }

    private func refreshLockStateForCurrentSetting() {
        isUnlocked = !effectiveSetting.pinEnabled
    }
}
