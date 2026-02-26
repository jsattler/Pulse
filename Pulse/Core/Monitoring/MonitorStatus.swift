import AppKit
import SwiftUI

/// The health status of a monitor.
///
/// Cases align with the BetterStack status page API values.
enum MonitorStatus: String, Sendable, Comparable {
    case unknown
    case operational
    case degraded
    case downtime
    case maintenance

    /// SwiftUI display color for this status.
    var color: Color {
        switch self {
        case .unknown: Color(red: 1.0, green: 1.0, blue: 1.0)
        case .operational: Color(red: 0.20, green: 0.84, blue: 0.29)
        case .degraded: Color(red: 1.0, green: 0.62, blue: 0.04)
        case .downtime: Color(red: 1.0, green: 0.23, blue: 0.19)
        case .maintenance: Color(red: 0.35, green: 0.56, blue: 0.97)
        }
    }

    /// AppKit display color for this status, using explicit sRGB values
    /// so the color renders correctly on transparent NSPanel backgrounds.
    var nsColor: NSColor {
        switch self {
        case .unknown: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        case .operational: NSColor(srgbRed: 0.20, green: 0.84, blue: 0.29, alpha: 1)
        case .degraded: NSColor(srgbRed: 1.0, green: 0.62, blue: 0.04, alpha: 1)
        case .downtime: NSColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1)
        case .maintenance: NSColor(srgbRed: 0.35, green: 0.56, blue: 0.97, alpha: 1)
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
        case .operational: "Operational"
        case .degraded: "Degraded"
        case .downtime: "Downtime"
        case .maintenance: "Maintenance"
        }
    }

    /// Severity rank used for ordering and aggregate calculations.
    /// Higher values represent worse states.
    private var severity: Int {
        switch self {
        case .unknown: 0
        case .operational: 1
        case .maintenance: 2
        case .degraded: 3
        case .downtime: 4
        }
    }

    static func < (lhs: MonitorStatus, rhs: MonitorStatus) -> Bool {
        lhs.severity < rhs.severity
    }
}

// MARK: - Decodable

extension MonitorStatus: Decodable {
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = MonitorStatus(rawValue: rawValue) ?? .unknown
    }
}
