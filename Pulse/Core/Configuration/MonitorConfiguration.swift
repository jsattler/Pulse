import Foundation

// MARK: - Root Configuration

/// Root configuration loaded from `~/.config/isup/config.json`.
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

    /// The monitors associated with this provider.
    var monitors: [Monitor]
}

// MARK: - Monitor

/// A single monitor within a service provider.
///
/// Exactly one of the type-specific properties (`http`, `tcp`, `betterstack`,
/// `atlassian`, `statusio`, `incidentio`) must be set. The presence of that
/// key determines the monitor type.
struct Monitor: Codable, Sendable, Identifiable, Equatable {
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
enum MonitorType: String, Codable, Sendable {
    case http
    case tcp
    case betterstack
    case atlassian
    case statusio
    case incidentio
}

// MARK: - HTTP Monitor

/// Configuration for an HTTP health check monitor.
struct HTTPMonitorConfig: Codable, Sendable, Equatable {
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
struct RequestHeader: Codable, Sendable, Equatable {
    var name: String
    var value: String
}

// MARK: - TCP Monitor

/// Configuration for a TCP connectivity check monitor.
struct TCPMonitorConfig: Codable, Sendable, Equatable {
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
struct StatusPageMonitorConfig: Codable, Sendable, Equatable {
    /// The status page URL.
    var url: String

    /// The feed format to consume (e.g. "rss", "json", "atom").
    var format: String?
}
