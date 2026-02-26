import SwiftUI

/// The main menu bar panel for Pulse, showing service provider health at a glance.
struct MenuBarView: View {
    var configManager: ConfigManager
    var monitorEngine: MonitorEngine
    var faviconStore: FaviconStore?

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            if let providers = configManager.configuration?.serviceProviders,
               !providers.isEmpty {
                providerList(providers)
            } else {
                emptyState
            }

            MenuBarDivider()

            // Bottom actions
            MenuBarActionButton(title: "Settings...", systemImage: "gear") {
                NSApplication.shared.activate()
                openSettings()
            }

            MenuBarActionButton(title: "Quit Pulse", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .frame(width: 320)
    }

    // MARK: - Provider List

    private func providerList(_ providers: [ServiceProvider]) -> some View {
        VStack(spacing: 0) {
            ForEach(providers) { provider in
                ServiceProviderRow(
                    provider: provider,
                    monitorStates: monitorEngine.statesByProvider[provider.name] ?? [],
                    websiteURL: monitorEngine.websiteURLsByProvider[provider.name],
                    faviconStore: faviconStore
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Monitors Configured")
                .font(.system(size: 13, weight: .medium))

            Button("Open Settings...") {
                NSApplication.shared.activate()
                openSettings()
            }
            .controlSize(.small)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Service Provider Row

/// An expandable row representing a service provider, with a status dot
/// inside a circle and a chevron to reveal individual monitors.
struct ServiceProviderRow: View {
    var provider: ServiceProvider
    var monitorStates: [MonitorState]
    var websiteURL: URL?
    var faviconStore: FaviconStore?

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    FaviconView(
                        websiteURL: websiteURL,
                        statusColor: aggregateStatus.color,
                        faviconStore: faviconStore
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(aggregateStatus.label)
                            .font(.system(size: 11))
                            .foregroundStyle(aggregateStatus == .operational ? .secondary : aggregateStatus.color)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? .gray.opacity(0.1) : .clear)
                    .padding(.horizontal, 4)
            )
            .onHover { hovering in
                isHovered = hovering
            }

            // Expanded monitor list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(monitorStates) { state in
                        MonitorRow(state: state)
                    }
                }
                .padding(.leading, 12)
                .background(.quaternary.opacity(0.3))
            }
        }
    }

    private var aggregateStatus: MonitorStatus {
        guard !monitorStates.isEmpty else { return .unknown }
        return monitorStates.map(\.status).max() ?? .unknown
    }
}

// MARK: - Monitor Row

/// A single monitor row inside an expanded service provider, with a
/// smaller status circle and the monitor's display name.
struct MonitorRow: View {
    var state: MonitorState

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: state.status)

            Text(state.displayName)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? .gray.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Status Dot

/// A small colored dot indicating the status of a monitor.
struct StatusDot: View {
    var status: MonitorStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}

// MARK: - Menu Bar Shared Components

/// A styled action button for the menu bar panel with hover effect.
struct MenuBarActionButton: View {
    let title: String
    var systemImage: String? = nil
    var accentColor: Color = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(accentColor.opacity(0.8))
                    }
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? accentColor.opacity(0.1) : .clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// A styled divider for menu bar sections.
struct MenuBarDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}
