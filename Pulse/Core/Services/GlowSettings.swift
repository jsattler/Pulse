import Foundation
import Observation

/// Describes when a glow behaviour should be suppressed.
enum GlowCondition: String, CaseIterable, Identifiable, Sendable {
    /// Never suppress — the behaviour is always active.
    case never = "Never"
    /// Suppress only while the aggregate status is operational.
    case whenOperational = "When Operational"
    /// Always suppress — the behaviour is permanently disabled.
    case always = "Always"

    var id: String { rawValue }
}

/// User-configurable preferences for the notch glow effect.
///
/// Backed by `UserDefaults` for persistence. Each property uses a stored
/// field so the `@Observable` macro can track reads/writes and trigger
/// SwiftUI updates immediately when a setting changes.
@Observable
@MainActor
final class GlowSettings {

    // MARK: - UserDefaults keys

    private enum Key {
        static let hideGlow = "hideGlow"
        static let disablePulse = "disablePulse"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Register defaults so first-launch values are sensible:
        // glow always visible, pulse disabled when operational.
        defaults.register(defaults: [
            Key.hideGlow: GlowCondition.never.rawValue,
            Key.disablePulse: GlowCondition.whenOperational.rawValue,
        ])

        // Hydrate stored fields from persisted values.
        _hideGlow = GlowCondition(rawValue: defaults.string(forKey: Key.hideGlow) ?? "") ?? .never
        _disablePulse = GlowCondition(rawValue: defaults.string(forKey: Key.disablePulse) ?? "") ?? .whenOperational
    }

    // MARK: - Settings

    /// When to hide the notch glow entirely.
    var hideGlow: GlowCondition {
        didSet { defaults.set(hideGlow.rawValue, forKey: Key.hideGlow) }
    }

    /// When to disable the pulsing (breathing) animation, showing
    /// a static glow at full brightness instead.
    var disablePulse: GlowCondition {
        didSet { defaults.set(disablePulse.rawValue, forKey: Key.disablePulse) }
    }
}
