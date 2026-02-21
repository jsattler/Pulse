import AppKit
import SwiftUI

/// The health status of a monitor.
enum MonitorStatus: String, Sendable, Comparable {
    case unknown
    case up
    case degraded
    case down

    /// SwiftUI display color for this status.
    var color: Color {
        Color(nsColor: nsColor)
    }

    /// AppKit display color for this status, using explicit sRGB values
    /// so the color renders correctly on transparent NSPanel backgrounds.
    var nsColor: NSColor {
        switch self {
        case .unknown: NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1)
        case .up: NSColor(srgbRed: 0.20, green: 0.84, blue: 0.29, alpha: 1)
        case .degraded: NSColor(srgbRed: 1.0, green: 0.62, blue: 0.04, alpha: 1)
        case .down: NSColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1)
        }
    }

    /// A non-template NSImage of a filled circle in this status color,
    /// suitable for use as a menu bar icon (AppKit won't recolor it).
    var menuBarDotImage: NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            nsColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Human-readable label for the notch overlay subtitle.
    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .up: "Operational"
        case .degraded: "Degraded"
        case .down: "Interruption"
        }
    }

    /// SF Symbol name representing this status.
    var iconName: String {
        switch self {
        case .unknown: "questionmark"
        case .up: "arrowshape.up"
        case .degraded: "arrowshape.forward"
        case .down: "arrowshape.down"
        }
    }

    /// Severity rank used for ordering and aggregate calculations.
    /// Higher values represent worse states.
    private var severity: Int {
        switch self {
        case .unknown: 0
        case .up: 1
        case .degraded: 2
        case .down: 3
        }
    }

    static func < (lhs: MonitorStatus, rhs: MonitorStatus) -> Bool {
        lhs.severity < rhs.severity
    }
}
