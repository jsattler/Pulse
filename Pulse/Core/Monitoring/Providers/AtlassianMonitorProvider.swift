import Foundation
import os

/// Checks an Atlassian Statuspage via its public JSON API and returns
/// per-component results.
///
/// Uses the `/api/v2/components.json` endpoint to fetch component statuses
/// and maps Atlassian status strings to ``MonitorStatus`` values.
struct AtlassianMonitorProvider: AggregatedMonitorProvider {
    private let config: StatusPageMonitorConfig
    private let session: URLSession
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "AtlassianMonitor")

    init(config: StatusPageMonitorConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func check() async throws -> AggregatedCheckResult {
        let endpointURL = componentsEndpointURL()

        guard let url = endpointURL else {
            logger.warning("Invalid Atlassian status page URL: \(config.url)")
            return AggregatedCheckResult(
                components: [
                    ComponentCheckResult(
                        componentName: config.url,
                        result: CheckResult(
                            status: .downtime,
                            timestamp: .now,
                            message: "Invalid URL: \(config.url)"
                        )
                    ),
                ]
            )
        }

        let request = URLRequest(url: url)
        let data: Data

        do {
            (data, _) = try await session.data(for: request)
        } catch {
            logger.warning("Atlassian fetch failed for \(url): \(error.localizedDescription)")
            throw error
        }

        let response: AtlassianComponentsResponse

        do {
            response = try JSONDecoder().decode(AtlassianComponentsResponse.self, from: data)
        } catch {
            logger.warning("Atlassian JSON decode failed: \(error.localizedDescription)")
            throw error
        }

        let websiteURL = URL(string: response.page.url)

        guard !response.components.isEmpty else {
            return AggregatedCheckResult(
                components: [
                    ComponentCheckResult(
                        componentName: response.page.name,
                        result: CheckResult(status: .unknown, timestamp: .now)
                    ),
                ],
                websiteURL: websiteURL
            )
        }

        logger.debug("Atlassian check for \(config.url): \(response.components.count) components")

        let components = response.components.compactMap { component -> ComponentCheckResult? in
            // Skip group headers — they have no meaningful status of their own.
            if component.group == true { return nil }

            let status = mapStatus(component.status)
            guard status != .unknown else { return nil }

            return ComponentCheckResult(
                componentName: component.name,
                result: CheckResult(status: status, timestamp: .now)
            )
        }

        return AggregatedCheckResult(components: components, websiteURL: websiteURL)
    }

    // MARK: - Helpers

    /// Builds the components endpoint URL by appending `/api/v2/components.json`
    /// to the configured status page URL.
    private func componentsEndpointURL() -> URL? {
        guard var url = URL(string: config.url) else { return nil }
        if url.path().hasSuffix("/") {
            url = url.deletingLastPathComponent()
        }
        return url.appending(path: "api/v2/components.json")
    }

    /// Maps an Atlassian component status string to a ``MonitorStatus``.
    private func mapStatus(_ status: String) -> MonitorStatus {
        switch status {
        case "operational": .operational
        case "degraded_performance": .degraded
        case "partial_outage": .degraded
        case "major_outage": .downtime
        case "under_maintenance": .maintenance
        default: .unknown
        }
    }
}

// MARK: - Atlassian Response Types

/// Response from the `/api/v2/components.json` endpoint.
private struct AtlassianComponentsResponse: Decodable {
    var page: Page
    var components: [Component]

    struct Page: Decodable {
        var id: String
        var name: String
        var url: String
    }

    struct Component: Decodable {
        var id: String
        var name: String
        var status: String
        var group: Bool?
    }
}
