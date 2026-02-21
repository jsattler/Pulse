import SwiftUI

/// A compact status indicator for the notch overlay.
///
/// Smaller than the menu bar `StatusDot` to fit the denser overlay layout.
struct NotchStatusDot: View {
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}
