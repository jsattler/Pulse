import SwiftUI

/// A collapsible service provider row for the notch overlay.
///
/// Shows a status indicator, service name, aggregate heartbeat graph,
/// and a chevron that expands to reveal individual monitor rows.
struct NotchServiceRow: View {
    var providerName: String
    var monitorStates: [MonitorState]
    var websiteURL: URL?
    var statusPageURL: URL?
    var glowSettings: GlowSettings?
    var faviconStore: FaviconStore?
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    FaviconView(
                        websiteURL: websiteURL,
                        statusColor: aggregateColor,
                        size: 18,
                        faviconStore: faviconStore
                    )
                    .padding(.trailing, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(providerName)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(aggregateStatus.label)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }

                    Spacer()

                    actionButtons

                    HeartbeatGraphView(
                        results: aggregateRecentResults,
                        color: aggregateColor
                    )

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(isHovering ? 0.08 : 0))
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(monitorStates) { state in
                        NotchMonitorRow(state: state)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }

    // MARK: - Actions

    private var isSilenced: Bool {
        glowSettings?.isSilenced(providerName) ?? false
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
            if let statusPageURL {
                Button {
                    NSWorkspace.shared.open(statusPageURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 26, height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Open status page")
            }

            Button {
                glowSettings?.toggleSilence(for: providerName)
            } label: {
                Image(systemName: isSilenced ? "bell.slash.fill" : "bell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(isSilenced ? 0.8 : 0.4))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(isSilenced ? "Unmute alerts" : "Mute alerts")
        }
    }

    // MARK: - Helpers

    /// Aggregate status from the worst child monitor.
    private var aggregateStatus: MonitorStatus {
        guard !monitorStates.isEmpty else { return .unknown }
        return monitorStates.map(\.status).max() ?? .unknown
    }

    /// Aggregate status color from the worst child monitor.
    private var aggregateColor: Color {
        aggregateStatus.color
    }

    /// Merged recent results across all monitors for the aggregate heartbeat.
    /// Takes the worst status at each time slot.
    private var aggregateRecentResults: [CheckResult] {
        guard !monitorStates.isEmpty else { return [] }
        let maxCount = monitorStates.map(\.recentResults.count).max() ?? 0
        guard maxCount > 0 else { return [] }

        return (0..<maxCount).map { index in
            let worstStatus = monitorStates.compactMap { state -> MonitorStatus? in
                let offset = maxCount - state.recentResults.count
                guard index >= offset else { return nil }
                return state.recentResults[index - offset].status
            }.max() ?? .unknown

            return CheckResult(status: worstStatus, timestamp: .now)
        }
    }
}
