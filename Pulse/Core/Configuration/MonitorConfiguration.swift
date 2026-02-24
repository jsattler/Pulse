import Foundation

// MARK: - Root Configuration

/// Root configuration loaded from `~/.config/pulse/config.json`.
struct PulseConfiguration: Codable, Sendable, Equatable {
    /// Schema version identifier.
    var version: String

    /// Grouped service providers, each containing one or more monitors.
    var serviceProviders: [ServiceProvider]
}

// MARK: - Service Provider

/// A logical grouping of monitors for a single service (e.g. "OpenAI", "Anthropic").
struct ServiceProvider: Codable, Sendable, Identifiable, Equatable {
    var id: String { name }

    /// Human-readable name for this service provider.
    var name: String

    /// Optional website URL used to derive a favicon for display.
    /// For status page monitors the favicon is auto-derived when not set.
    var websiteURL: String?

    /// The monitors associated with this provider.
    var monitors: [Monitor]
}

// MARK: - Monitor

/// A single monitor within a service provider.
///
/// Exactly one of the type-specific properties (`http`, `tcp`, `betterstack`,
/// `atlassian`, `statusio`, `incidentio`) must be set. The presence of that
/// key determines the monitor type.
struct Monitor: Codable, Sendable, Identifiable, Hashable {
    var id: String { name }

    /// Human-readable name for this monitor.
    var name: String

    /// HTTP health check configuration.
    var http: HTTPMonitorConfig?

    /// TCP connectivity check configuration.
    var tcp: TCPMonitorConfig?

    /// Better Stack status page configuration.
    var betterstack: StatusPageMonitorConfig?

    /// Atlassian Statuspage configuration.
    var atlassian: StatusPageMonitorConfig?

    /// Status.io configuration.
    var statusio: StatusPageMonitorConfig?

    /// incident.io configuration.
    var incidentio: StatusPageMonitorConfig?

    /// The resolved monitor type based on which key is present.
    var resolvedType: MonitorType? {
        if http != nil { return .http }
        if tcp != nil { return .tcp }
        if betterstack != nil { return .betterstack }
        if atlassian != nil { return .atlassian }
        if statusio != nil { return .statusio }
        if incidentio != nil { return .incidentio }
        return nil
    }
}

// MARK: - Monitor Type

/// The supported monitor types, derived from which key is present on a `Monitor`.
enum MonitorType: String, Codable, Sendable, CaseIterable, Identifiable {
    case http
    case tcp
    case betterstack
    case atlassian
    case statusio
    case incidentio

    var id: String { rawValue }

    /// Human-readable label for display in the UI.
    var label: String {
        switch self {
        case .http: "HTTP"
        case .tcp: "TCP"
        case .betterstack: "Better Stack"
        case .atlassian: "Atlassian Statuspage"
        case .statusio: "Status.io"
        case .incidentio: "incident.io"
        }
    }

    /// Monitor types that have a fully implemented provider.
    static let implemented: [MonitorType] = [.http, .betterstack, .atlassian]

    /// Whether this type monitors a status page rather than probing directly.
    var isStatusPage: Bool {
        switch self {
        case .http, .tcp: false
        case .betterstack, .atlassian, .statusio, .incidentio: true
        }
    }
}

// MARK: - HTTP Monitor

/// Configuration for an HTTP health check monitor.
struct HTTPMonitorConfig: Codable, Sendable, Hashable {
    /// The URL to probe.
    var url: String

    /// HTTP method to use (e.g. "GET", "HEAD").
    var method: String?

    /// Interval between checks, in seconds.
    var checkFrequency: Int?

    /// Expected HTTP status codes. Defaults to `[200]` at runtime.
    var expectedStatusCodes: [Int]?

    /// Maximum acceptable response time in milliseconds.
    var maxLatency: Int?

    /// Consecutive failures before the monitor is considered down.
    var failureThreshold: Int?

    /// Custom request headers to include.
    var requestHeaders: [RequestHeader]?
}

/// A single HTTP request header.
struct RequestHeader: Codable, Sendable, Hashable {
    var name: String
    var value: String
}

// MARK: - TCP Monitor

/// Configuration for a TCP connectivity check monitor.
struct TCPMonitorConfig: Codable, Sendable, Hashable {
    /// The host to connect to.
    var host: String

    /// The port to connect to.
    var port: Int

    /// Interval between checks, in seconds.
    var checkFrequency: Int?

    /// Consecutive failures before the monitor is considered down.
    var failureThreshold: Int?
}

// MARK: - Status Page Monitor

/// Configuration for managed status page providers
/// (Better Stack, Atlassian, Status.io, incident.io).
struct StatusPageMonitorConfig: Codable, Sendable, Hashable {
    /// The status page URL.
    var url: String

    /// The feed format to consume (e.g. "rss", "json", "atom").
    var format: String?
}
