import SwiftUI

/// Preference key used to measure the service list content height
/// so the backing NSPanel can be resized to match.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A black overlay that expands downward from the notch using the
/// DynamicIslandShape when the user hovers over the notch area.
///
/// Shows live service provider status with expandable monitor rows
/// when expanded. The content height is measured and the backing
/// NSPanel is resized to fit.
struct NotchOverlayView: View {
    let controller: NotchController
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let menuBarHeight: CGFloat

    /// Whether the overlay is expanded (mouse is hovering).
    @State private var isExpanded = false

    /// Whether the content is visible. Becomes true only after the
    /// expand animation finishes so text doesn't appear while the
    /// shape is still growing.
    @State private var showContent = false

    /// Measured service list content height (includes inner padding).
    @State private var measuredContentHeight: CGFloat = 60

    // Shape parameters for collapsed / expanded states.
    private let collapsedInset: CGFloat = 8
    private let expandedInset: CGFloat = 16
    private let collapsedBottomRadius: CGFloat = 8
    private let expandedBottomRadius: CGFloat = 18

    /// Extra horizontal padding between the shape edge and content.
    private let contentInsetH: CGFloat = 14
    /// Extra bottom padding so content doesn't overlap the bottom radius curve.
    private let contentInsetBottom: CGFloat = 14

    /// 0 = collapsed, 1 = expanded. Animated for smooth interpolation.
    private var expansion: CGFloat { isExpanded ? 1 : 0 }

    /// Service providers from the configuration.
    private var serviceProviders: [ServiceProvider] {
        controller.configuration?.serviceProviders ?? []
    }

    /// Total overlay height when expanded.
    private var expandedHeight: CGFloat {
        menuBarHeight + measuredContentHeight + contentInsetBottom
    }

    var body: some View {
        GeometryReader { geo in
            let targetHeight = expandedHeight
            let currentHeight = notchHeight + (targetHeight - notchHeight) * expansion
            let expandedWidth = notchWidth + 300
            let currentWidth = notchWidth + (expandedWidth - notchWidth) * expansion
            let currentTopInset = collapsedInset + (expandedInset - collapsedInset) * expansion
            let currentBottomRadius = collapsedBottomRadius + (expandedBottomRadius - collapsedBottomRadius) * expansion

            let shape = DynamicIslandShape(
                topInset: currentTopInset,
                bottomRadius: currentBottomRadius
            )

            // Usable content width: shape width minus both side insets
            // and additional inner padding on each side.
            let innerWidth = max(0, currentWidth - (currentTopInset + contentInsetH) * 2)

            ZStack(alignment: .top) {
                shape
                    .fill(.black)
                    .frame(width: currentWidth, height: currentHeight)

                if showContent {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: menuBarHeight)

                        serviceListContent
                            .frame(width: innerWidth)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: ContentHeightKey.self, value: proxy.size.height)
                                }
                            )
                    }
                    .frame(width: currentWidth, height: targetHeight, alignment: .top)
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
                }
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .contentShape(shape)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    guard !isExpanded else { return }
                    controller.setOverlayExpanded(true)
                    withAnimation(.easeOut(duration: 0.3)) {
                        isExpanded = true
                    }
                    // Show content after the shape has finished expanding.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        if isExpanded {
                            showContent = true
                        }
                    }
                case .ended:
                    // Hide content immediately, then collapse the shape.
                    showContent = false
                    withAnimation(.easeIn(duration: 0.2)) {
                        isExpanded = false
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        if !isExpanded {
                            controller.setOverlayExpanded(false)
                        }
                    }
                }
            }
            .onPreferenceChange(ContentHeightKey.self) { height in
                guard height > 0, height != measuredContentHeight else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    measuredContentHeight = height
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var serviceListContent: some View {
        if serviceProviders.isEmpty {
            Text("No monitors configured")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(serviceProviders) { provider in
                    NotchServiceRow(
                        providerName: provider.name,
                        monitorStates: controller.monitorEngine?.statesByProvider[provider.name] ?? [],
                        websiteURL: controller.monitorEngine?.websiteURLsByProvider[provider.name],
                        statusPageURL: controller.monitorEngine?.statusPageURLsByProvider[provider.name],
                        glowSettings: controller.glowSettings,
                        faviconStore: controller.faviconStore
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}
