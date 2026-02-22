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

    private var glowPanel: NSPanel?
    private var overlayPanel: NSPanel?
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "NotchController")

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
    }

    func hide() {
        glowPanel?.orderOut(nil)
        glowPanel = nil
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    func setOverlayExpanded(_ expanded: Bool, contentHeight: CGFloat = 0) {
        isOverlayExpanded = expanded
        guard let panel = overlayPanel else { return }

        if expanded, contentHeight > 0 {
            let expandedWidth = notchWidth + 300
            // contentHeight is the measured total overlay height
            // (notch spacer + service list + padding).
            let expandedHeight = contentHeight
            overlayExpandedFrame = NSRect(
                x: notchMidX - expandedWidth / 2,
                y: screenFrame.maxY - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        }

        let frame = expanded ? overlayExpandedFrame : overlayCollapsedFrame
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Glow Panel

    private func showGlowPanel(screen: NSScreen, notchRect: NSRect) {
        // Margin for the blur spread (blur radius ~10pt needs room).
        // Bottom margin must be large enough for the blur to fully fade out.
        let margin: CGFloat = 24
        let bottomMargin: CGFloat = 48
        let panelWidth = notchWidth + margin * 2
        let panelHeight = hardwareNotchHeight + bottomMargin

        // Top of panel = top of screen.
        let x = notchRect.midX - panelWidth / 2
        let y = screen.frame.maxY - panelHeight

        let glowView = NotchGlowPanelView(
            controller: self,
            notchWidth: notchWidth,
            notchHeight: hardwareNotchHeight
        )

        let panel = makePanel(
            frame: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            content: glowView
        )
        panel.ignoresMouseEvents = true

        panel.orderFrontRegardless()
        glowPanel = panel
    }

    // MARK: - Overlay Panel

    private func showOverlayPanel(screen: NSScreen, notchRect: NSRect) {
        screenFrame = screen.frame
        notchMidX = notchRect.midX

        let expandedWidth = notchRect.width + 300
        let expandedHeight = menuBarHeight + 200

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
        panel.contentView = NSHostingView(rootView: content)
        return panel
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

    private var glowColor: Color {
        controller.monitorEngine?.aggregateStatus.color ?? .gray
    }

    var body: some View {
        NotchGlowView(
            glowColor: glowColor,
            notchWidth: notchWidth,
            notchHeight: notchHeight
        )
        .opacity(controller.isOverlayExpanded ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: controller.isOverlayExpanded)
    }
}
