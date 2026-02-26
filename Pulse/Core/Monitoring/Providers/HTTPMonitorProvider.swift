import Foundation
import os

/// Performs HTTP health checks against a configured endpoint.
struct HTTPMonitorProvider: MonitorProvider {
    private let config: HTTPMonitorConfig
    private let session: URLSession
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "HTTPMonitor")

    init(config: HTTPMonitorConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func check() async throws -> CheckResult {
        guard let url = URL(string: config.url) else {
            return CheckResult(
                status: .downtime,
                timestamp: .now,
                message: "Invalid URL: \(config.url)"
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = config.method ?? "GET"

        if let headers = config.requestHeaders {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }

        let start = ContinuousClock.now
        let response: URLResponse

        do {
            (_, response) = try await session.data(for: request)
        } catch {
            logger.warning("HTTP check failed for \(config.url): \(error.localizedDescription)")
            return CheckResult(
                status: .downtime,
                timestamp: .now,
                message: error.localizedDescription
            )
        }

        let elapsed = ContinuousClock.now - start
        let responseTime = elapsed

        guard let httpResponse = response as? HTTPURLResponse else {
            return CheckResult(
                status: .downtime,
                responseTime: responseTime,
                timestamp: .now,
                message: "Response was not HTTP."
            )
        }

        let expectedCodes = config.expectedStatusCodes ?? [200]
        let codeMatch = expectedCodes.contains(httpResponse.statusCode)

        let latencyExceeded: Bool
        if let maxLatency = config.maxLatency {
            latencyExceeded = elapsed > .milliseconds(maxLatency)
        } else {
            latencyExceeded = false
        }

        let status: MonitorStatus
        if !codeMatch {
            status = .downtime
        } else if latencyExceeded {
            status = .degraded
        } else {
            status = .operational
        }

        let message: String? = if !codeMatch {
            "HTTP \(httpResponse.statusCode) (expected \(expectedCodes))"
        } else if latencyExceeded, let maxLatency = config.maxLatency {
            "Latency \(elapsed) exceeds \(maxLatency)ms threshold"
        } else {
            nil
        }

        logger.debug("HTTP check \(config.url): status=\(status.rawValue) code=\(httpResponse.statusCode) time=\(elapsed)")

        return CheckResult(
            status: status,
            responseTime: responseTime,
            timestamp: .now,
            message: message
        )
    }
}
