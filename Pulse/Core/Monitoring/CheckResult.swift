import Foundation

/// The result of a single monitor check.
struct CheckResult: Sendable, Equatable {
    /// The determined health status.
    var status: MonitorStatus

    /// Response time in milliseconds, if applicable.
    var responseTime: Duration?

    /// When this check was performed.
    var timestamp: Date

    /// Optional human-readable error or detail message.
    var message: String?
}

/// The result of a single component within an aggregated monitor check.
struct ComponentCheckResult: Sendable, Equatable {
    /// The component name as reported by the status page (e.g. "API", "ChatGPT").
    var componentName: String

    /// The check result for this component.
    var result: CheckResult
}
