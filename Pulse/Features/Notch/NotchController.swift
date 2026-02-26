import AppKit
import os
import SwiftUI

/// Manages the notch glow and hover overlay panels.
///
/// Both panels use the same approach: a SwiftUI view inside an
/// `NSHostingView` on a transparent borderless `NSPanel` at
/// `.screenSaver` level.
@Observable
@MainActor
final class NotchController {

    var isOverlayExpanded = false

    /// The monitor engine whose state is displayed in the overlay.
    var monitorEngine: MonitorEngine?

    /// The current configuration providing service provider metadata.
    var configuration: PulseConfiguration?

    /// User-configurable glow preferences.
    var glowSettings: GlowSettings?

    /// Shared favicon store for displaying cached favicons.
    var faviconStore: FaviconStore?

    fileprivate var glowPanel: NSPanel?
    private var overlayPanel: NSPanel?
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "NotchController")
    private var screenObservers: [NSObjectProtocol] = []

    // Cached geometry
    private var notchWidth: CGFloat = 0
    private var notchHeight: CGFloat = 0
    /// The visible camera housing height (shorter than the full safe
    /// area inset). Used for the glow border sizing.
    private var hardwareNotchHeight: CGFloat = 0
    private var menuBarHeight: CGFloat = 0
    private var screenFrame: NSRect = .zero
    private var notchMidX: CGFloat = 0

    // Overlay sizing
    private var overlayCollapsedFrame: NSRect = .zero
    private var overlayExpandedFrame: NSRect = .zero

    // MARK: - Public API

    func show() {
        guard let screen = NSScreen.builtIn, screen.hasNotch,
              let notchRect = screen.notchRect else {
            logger.info("No notch detected, skipping notch UI.")
            return
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        notchWidth = notchRect.width
        notchHeight = notchRect.height
        // The safe area inset includes the menu bar region below the
        // notch. The actual camera housing is roughly a third of that.
        hardwareNotchHeight = round(notchHeight / 3)

        showGlowPanel(screen: screen, notchRect: notchRect)
        showOverlayPanel(screen: screen, notchRect: notchRect)
        startScreenObservers()
    }

    func hide() {
        stopScreenObservers()
        glowPanel?.orderOut(nil)
        glowPanel = nil
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    func setOverlayExpanded(_ expanded: Bool) {
        isOverlayExpanded = expanded
        guard let panel = overlayPanel else { return }

        let frame = expanded ? overlayExpandedFrame : overlayCollapsedFrame
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Glow Panel

    private func showGlowPanel(screen: NSScreen, notchRect: NSRect) {
        let glowSize = glowSettings?.glowSize ?? 1.0
        let frame = glowPanelFrame(notchMidX: notchRect.midX, screenMaxY: screen.frame.maxY, glowSize: glowSize)

        let glowView = NotchGlowPanelView(
            controller: self,
            notchWidth: notchWidth,
            notchHeight: hardwareNotchHeight,
            notchMidX: notchRect.midX,
            screenMaxY: screen.frame.maxY,
            glowSettings: glowSettings
        )

        let panel = makePanel(frame: frame, content: glowView)
        panel.ignoresMouseEvents = true

        panel.orderFrontRegardless()
        glowPanel = panel
    }

    /// Computes the glow panel frame, scaling margins with `glowSize` so the
    /// blur never clips at the panel boundary.
    func glowPanelFrame(notchMidX: CGFloat, screenMaxY: CGFloat, glowSize: CGFloat) -> NSRect {
        // Base margins sized for the default blur radius (12pt).
        // Scaled by glowSize so larger blurs always fit within the panel.
        let margin: CGFloat = 24 * glowSize
        let bottomMargin: CGFloat = 48 * glowSize
        let panelWidth = notchWidth + margin * 2
        let panelHeight = hardwareNotchHeight + bottomMargin
        let x = notchMidX - panelWidth / 2
        let y = screenMaxY - panelHeight
        return NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    // MARK: - Overlay Panel

    private func showOverlayPanel(screen: NSScreen, notchRect: NSRect) {
        screenFrame = screen.frame
        notchMidX = notchRect.midX

        let expandedWidth = notchRect.width + 300
        let expandedHeight = menuBarHeight + 600

        overlayCollapsedFrame = NSRect(
            x: notchMidX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        overlayExpandedFrame = NSRect(
            x: notchMidX - expandedWidth / 2,
            y: screenFrame.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )

        let overlayView = NotchOverlayView(
            controller: self,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            menuBarHeight: menuBarHeight
        )

        let panel = makePanel(
            frame: overlayCollapsedFrame,
            content: overlayView
        )
        panel.ignoresMouseEvents = false

        panel.orderFrontRegardless()
        overlayPanel = panel
    }

    // MARK: - Screen Observers

    private func startScreenObservers() {
        stopScreenObservers()
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter

        let screenChanged = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionPanels()
            }
        }
        let woke = workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Screen geometry may not be updated immediately after wake.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.repositionPanels()
            }
        }
        screenObservers = [screenChanged, woke]
    }

    private func stopScreenObservers() {
        for observer in screenObservers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        screenObservers.removeAll()
    }

    private func repositionPanels() {
        hide()
        show()
    }

    // MARK: - Helpers

    private func makePanel<V: View>(frame: NSRect, content: V) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.level = .screenSaver
        panel.contentView = SafeNSHostingView(rootView: content)
        return panel
    }
}

// MARK: - Safe Hosting View

/// An `NSHostingView` subclass that guards against layout recursion.
///
/// When SwiftUI content inside a borderless `NSPanel` triggers a
/// layout pass, `NSHostingView` can call `layoutSubtreeIfNeeded`
/// recursively. This subclass detects the re-entrant call and
/// defers it to the next run-loop turn instead of recursing.
private final class SafeNSHostingView<Content: View>: NSHostingView<Content> {
    private var isInLayout = false

    override func layout() {
        guard !isInLayout else { return }
        isInLayout = true
        super.layout()
        isInLayout = false
    }
}

// MARK: - Glow Panel Wrapper

/// Wrapper that observes the monitor engine's aggregate status and
/// `isOverlayExpanded` from the controller, passing the derived glow
/// color to the glow view so it updates reactively.
private struct NotchGlowPanelView: View {
    let controller: NotchController
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchMidX: CGFloat
    let screenMaxY: CGFloat
    var glowSettings: GlowSettings?

    /// Aggregate status, excluding silenced providers.
    /// Returns `nil` when there is no engine or every provider is
    /// silenced — meaning there is nothing to report.
    private var aggregateStatus: MonitorStatus? {
        guard let engine = controller.monitorEngine else { return nil }
        let silenced = glowSettings?.silencedProviders ?? []
        let allStates = engine.statesByProvider
            .filter { !silenced.contains($0.key) }
            .values.flatMap { $0 }
        guard !allStates.isEmpty else { return nil }
        return allStates.map(\.status).max() ?? .unknown
    }

    private var glowColor: Color {
        aggregateStatus?.color ?? .clear
    }

    /// Whether the glow should be visible based on user preferences.
    private var isGlowVisible: Bool {
        guard let status = aggregateStatus else { return false }
        guard let settings = glowSettings else { return true }
        switch settings.hideGlow {
        case .always: return false
        case .whenOperational: return status != .operational
        case .never: return true
        }
    }

    /// Whether the pulsing animation should be active.
    private var shouldPulse: Bool {
        guard let status = aggregateStatus else { return false }
        guard let settings = glowSettings else { return true }
        switch settings.disablePulse {
        case .always: return false
        case .whenOperational: return status != .operational
        case .never: return true
        }
    }

    var body: some View {
        let glowSize = glowSettings?.glowSize ?? 1.0
        NotchGlowView(
            glowColor: glowColor,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            isPulseEnabled: shouldPulse,
            glowSize: glowSize
        )
        .opacity(controller.isOverlayExpanded || !isGlowVisible ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: controller.isOverlayExpanded)
        .animation(.easeInOut(duration: 0.3), value: isGlowVisible)
        .onChange(of: glowSize) { _, newSize in
            guard let panel = controller.glowPanel else { return }
            let frame = controller.glowPanelFrame(
                notchMidX: notchMidX,
                screenMaxY: screenMaxY,
                glowSize: newSize
            )
            panel.setFrame(frame, display: true, animate: false)
        }
    }
}
