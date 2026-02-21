import SwiftUI

/// A colored dot displayed in the menu bar that reflects the aggregate
/// monitor status: green = all up, yellow = degraded, red = down or unknown.
struct MenuBarStatusDot: View {
    var monitorEngine: MonitorEngine

    var body: some View {
        Image(nsImage: monitorEngine.aggregateStatus.menuBarDotImage)
    }
}
