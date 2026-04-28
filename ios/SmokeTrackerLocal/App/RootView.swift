import SwiftUI
import SwiftData
import WidgetKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSetting]

    @State private var isUnlocked = true
    @State private var showActionButtonLaunchPicker = false
    @State private var launchPickerChoices: [TriggerPrimary] = []
    @State private var launchPickerPosition: ActionButtonPickerPosition = .center
    @State private var dataRefreshSignal = UUID()

    var body: some View {
        let setting = effectiveSetting

        ZStack {
            TabView {
                HomeView(
                    viewModel: HomeViewModel(context: modelContext, setting: setting),
                    refreshSignal: dataRefreshSignal
                )
                    .id(homeViewIdentity)
                    .tabItem {
                        Label("记录", systemImage: "plus.circle")
                    }

                HistoryView(
                    viewModel: HistoryViewModel(context: modelContext),
                    refreshSignal: dataRefreshSignal
                )
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
                    onUnlocked: {
                        isUnlocked = true
                        presentLaunchPickerIfNeeded()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if showActionButtonLaunchPicker && !shouldShowLockGate {
                ActionButtonLaunchPickerOverlay(
                    choices: launchPickerChoices,
                    position: launchPickerPosition,
                    onSelect: handleLaunchPickerSelection,
                    onCancel: { showActionButtonLaunchPicker = false }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onAppear {
            _ = AppSetting.fetchOrCreate(in: modelContext)
            refreshLockStateForCurrentSetting()
            processPendingRequestsAndRefreshUI()
            presentLaunchPickerIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                if setting.pinEnabled {
                    isUnlocked = false
                }
            case .active:
                refreshLockStateForCurrentSetting()
                processPendingRequestsAndRefreshUI()
                presentLaunchPickerIfNeeded()
            @unknown default:
                break
            }
        }
        .onChange(of: setting.pinEnabled) { _, enabled in
            if !enabled {
                isUnlocked = true
                presentLaunchPickerIfNeeded()
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

    private func presentLaunchPickerIfNeeded() {
        guard !shouldShowLockGate else { return }
        guard WidgetQuickRecordStore.consumeLaunchPickerRequest() else { return }

        let rawChoices = WidgetQuickRecordStore.loadActionButtonChoices()
        let mapped = rawChoices.compactMap(TriggerPrimary.init(rawValue:))
        launchPickerChoices = mapped.isEmpty
            ? WidgetQuickRecordStore.defaultMedium.compactMap(TriggerPrimary.init(rawValue:))
            : mapped
        launchPickerPosition = WidgetQuickRecordStore.loadActionButtonPickerPosition()
        showActionButtonLaunchPicker = true
    }

    private func handleLaunchPickerSelection(_ trigger: TriggerPrimary) {
        let setting = AppSetting.fetchOrCreate(in: modelContext)
        let timeZone = TimeZone(identifier: setting.timezoneIdentifier) ?? .current
        let flow = CravingFlowService(logWriter: LogWriteService(timeZone: timeZone))
        _ = try? flow.createPendingCraving(in: modelContext, trigger: trigger, at: Date())
        WidgetCenter.shared.reloadAllTimelines()
        dataRefreshSignal = UUID()
        showActionButtonLaunchPicker = false
    }

    private func processPendingRequestsAndRefreshUI() {
        let inserted = WidgetQuickRecordProcessor.processPendingRequests(in: modelContext)
        if inserted > 0 {
            dataRefreshSignal = UUID()
        }
    }
}
