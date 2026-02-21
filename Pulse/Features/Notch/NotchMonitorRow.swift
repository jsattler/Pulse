import SwiftUI

/// A single monitor row inside the notch overlay.
///
/// Shows a status indicator, monitor name, and heartbeat graph.
struct NotchMonitorRow: View {
    var state: MonitorState
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            NotchStatusDot(color: state.status.color)

            Text(state.displayName)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            HeartbeatGraphView(
                results: state.recentResults,
                color: state.status.color
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(isHovering ? 0.08 : 0))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
