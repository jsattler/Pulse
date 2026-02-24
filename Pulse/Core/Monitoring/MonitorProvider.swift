import Foundation

/// A provider that checks a single endpoint and returns one result.
protocol MonitorProvider: Sendable {
    /// Performs a health check and returns the result.
    func check() async throws -> CheckResult
}

/// A provider that checks a status page and returns results for multiple components.
///
/// Status pages (e.g. BetterStack) report the health of multiple components
/// from a single URL. Each component becomes a flat monitor row in the UI.
protocol AggregatedMonitorProvider: Sendable {
    /// Performs a health check and returns results per component.
    func check() async throws -> AggregatedCheckResult
}

/// The combined result of an aggregated status page check.
struct AggregatedCheckResult: Sendable, Equatable {
    /// Per-component check results.
    var components: [ComponentCheckResult]

    /// A website URL discovered from the status page response,
    /// used to derive a favicon via the Google Favicon API.
    var websiteURL: URL?
}
