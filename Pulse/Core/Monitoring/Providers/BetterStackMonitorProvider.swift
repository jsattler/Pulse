import Foundation
import os

/// Checks a BetterStack status page and returns per-component results.
///
/// Currently returns mock data. The real JSON and Atom parsers will be
/// implemented in a future task (3.3).
struct BetterStackMonitorProvider: AggregatedMonitorProvider {
    private let config: StatusPageMonitorConfig
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "BetterStackMonitor")

    init(config: StatusPageMonitorConfig) {
        self.config = config
    }

    func check() async throws -> [ComponentCheckResult] {
        // TODO: Implement real JSON and Atom parsers (task 3.3).
        logger.debug("BetterStack mock check for \(config.url) (format: \(config.format ?? "json"))")

        return [
            ComponentCheckResult(
                componentName: "Website",
                result: CheckResult(
                    status: .up,
                    timestamp: .now
                )
            ),
            ComponentCheckResult(
                componentName: "API",
                result: CheckResult(
                    status: .up,
                    timestamp: .now
                )
            ),
            ComponentCheckResult(
                componentName: "Dashboard",
                result: CheckResult(
                    status: .degraded,
                    timestamp: .now,
                    message: "Mock degraded status"
                )
            ),
        ]
    }
}
