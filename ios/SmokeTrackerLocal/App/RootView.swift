import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            HomeView(viewModel: HomeViewModel(context: modelContext))
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
    }
}

