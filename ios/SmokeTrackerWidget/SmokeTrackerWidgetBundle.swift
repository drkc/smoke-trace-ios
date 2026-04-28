import WidgetKit
import SwiftUI

@main
struct SmokeTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
        SmokingDashboardWidget()
        SmokingMiniDashboardWidget()
    }
}
