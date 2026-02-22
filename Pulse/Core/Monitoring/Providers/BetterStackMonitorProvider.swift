import Foundation
import os

/// Checks a BetterStack status page via its public JSON API and returns
/// per-resource component results.
///
/// Appends `/index.json` to the configured status page URL and parses
/// the JSON:API response to extract resource statuses.
struct BetterStackMonitorProvider: AggregatedMonitorProvider {
    private let config: StatusPageMonitorConfig
    private let session: URLSession
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "BetterStackMonitor")

    /// Uses an ephemeral session to prevent `URLSession.shared` from caching
    /// the `alt-svc: h3` header that BetterStack returns. Without this,
    /// the shared session attempts an HTTP/3 (QUIC) connection upgrade in the
    /// background, which times out and produces `nw_read_request_report`
    /// "Operation timed out" warnings.
    init(config: StatusPageMonitorConfig, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.config = config
        self.session = session
    }

    func check() async throws -> [ComponentCheckResult] {
        let endpointURL = jsonEndpointURL()

        guard let url = endpointURL else {
            logger.warning("Invalid BetterStack status page URL: \(config.url)")
            return [
                ComponentCheckResult(
                    componentName: config.url,
                    result: CheckResult(
                        status: .downtime,
                        timestamp: .now,
                        message: "Invalid URL: \(config.url)"
                    )
                ),
            ]
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data

        do {
            (data, _) = try await session.data(for: request)
        } catch {
            logger.warning("BetterStack fetch failed for \(url): \(error.localizedDescription)")
            throw error
        }

        let response: BetterStackResponse

        do {
            response = try JSONDecoder().decode(BetterStackResponse.self, from: data)
        } catch {
            logger.warning("BetterStack JSON decode failed: \(error.localizedDescription)")
            throw error
        }

        let resources = response.included.filter { $0.type == "status_page_resource" }

        guard !resources.isEmpty else {
            // No resources found — report aggregate state from the page itself.
            let status = response.data.attributes.aggregateState ?? .unknown
            return [
                ComponentCheckResult(
                    componentName: response.data.attributes.companyName ?? config.url,
                    result: CheckResult(status: status, timestamp: .now)
                ),
            ]
        }

        logger.debug("BetterStack check for \(config.url): \(resources.count) resources")

        return resources.compactMap { resource -> ComponentCheckResult? in
            guard let name = resource.attributes.publicName,
                  let status = resource.attributes.status,
                  status != .unknown
            else { return nil }
            return ComponentCheckResult(
                componentName: name,
                result: CheckResult(status: status, timestamp: .now)
            )
        }
    }

    // MARK: - Helpers

    /// Builds the JSON API endpoint URL by appending `/index.json` to the
    /// configured status page URL.
    private func jsonEndpointURL() -> URL? {
        guard var url = URL(string: config.url) else { return nil }
        // Strip trailing slash before appending the path.
        if url.path().hasSuffix("/") {
            url = url.deletingLastPathComponent()
        }
        return url.appending(path: "index.json")
    }
}

// MARK: - BetterStack JSON:API Response Types

/// Top-level JSON:API response from a BetterStack status page.
private struct BetterStackResponse: Decodable {
    var data: StatusPageData
    var included: [IncludedResource]

    struct StatusPageData: Decodable {
        var attributes: StatusPageAttributes
    }

    struct StatusPageAttributes: Decodable {
        var companyName: String?
        var aggregateState: MonitorStatus?

        enum CodingKeys: String, CodingKey {
            case companyName = "company_name"
            case aggregateState = "aggregate_state"
        }
    }

    struct IncludedResource: Decodable {
        var type: String
        var attributes: ResourceAttributes
    }

    struct ResourceAttributes: Decodable {
        var publicName: String?
        var status: MonitorStatus?

        enum CodingKeys: String, CodingKey {
            case publicName = "public_name"
            case status
        }
    }
}
