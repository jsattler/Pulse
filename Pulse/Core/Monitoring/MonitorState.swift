import Foundation

/// A unique identifier for a runtime monitor, combining provider name and monitor/component name.
struct MonitorStateID: Hashable, Sendable {
    /// The service provider this monitor belongs to.
    var providerName: String

    /// The config-level monitor name.
    var monitorName: String

    /// For aggregated providers, the component name (e.g. "API", "ChatGPT").
    /// `nil` for single-result monitors like HTTP.
    var componentName: String?
}

/// Live runtime state for a single monitor (or component of an aggregated monitor).
struct MonitorState: Identifiable, Sendable, Equatable {
    var id: MonitorStateID

    /// The display name shown in the UI.
    var displayName: String

    /// Current health status.
    var status: MonitorStatus

    /// The most recent check result.
    var lastResult: CheckResult?

    /// Rolling window of recent check results for heartbeat display.
    var recentResults: [CheckResult] = []

    /// Maximum number of recent results to retain.
    static let maxRecentResults = 20

    /// Consecutive failure count (status != .up).
    var consecutiveFailures: Int

    /// The monitor type for display badges.
    var monitorType: MonitorType
}
