import SwiftUI
import SwiftData

@main
struct SmokeTrackerLocalApp: App {
    var sharedModelContainer: ModelContainer = SharedModelContainerFactory.shared

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
