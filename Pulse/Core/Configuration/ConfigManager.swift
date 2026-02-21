import Foundation
import Observation
import os

/// Manages loading, validating, and watching the Pulse configuration file.
///
/// The default configuration path is `~/.config/isup/config.json`.
@Observable
@MainActor
final class ConfigManager {
    /// The currently loaded configuration, or `nil` if not yet loaded.
    private(set) var configuration: PulseConfiguration?

    /// The last error encountered during loading.
    private(set) var lastError: ConfigurationError?

    /// Whether the configuration has been loaded successfully at least once.
    var isLoaded: Bool { configuration != nil }

    private let fileURL: URL
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "ConfigManager")
    @ObservationIgnored nonisolated(unsafe) private var watchTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultConfigURL
    }

    deinit {
        watchTask?.cancel()
    }

    // MARK: - Default Path

    /// Default configuration file location: `~/.config/isup/config.json`.
    static var defaultConfigURL: URL {
        URL.homeDirectory
            .appending(path: ".config/isup/config.json")
    }

    // MARK: - Loading

    /// Loads configuration from disk. Creates a default config if none exists.
    func load() {
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path()) {
                try createDefaultConfig()
            }

            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PulseConfiguration.self, from: data)
            try validate(decoded)

            configuration = decoded
            lastError = nil
            logger.info("Configuration loaded successfully from \(self.fileURL.path())")
        } catch let error as ConfigurationError {
            lastError = error
            logger.error("Configuration error: \(error.localizedDescription)")
        } catch let error as DecodingError {
            lastError = .decodingFailed(error)
            logger.error("Decoding error: \(error.localizedDescription)")
        } catch {
            lastError = .decodingFailed(error)
            logger.error("Unexpected error loading config: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    /// Validates a decoded configuration.
    private func validate(_ config: PulseConfiguration) throws(ConfigurationError) {
        for provider in config.serviceProviders {
            if provider.name.isEmpty {
                throw .validationFailed("Service provider name must not be empty.")
            }
            for monitor in provider.monitors {
                if monitor.name.isEmpty {
                    throw .validationFailed(
                        "Monitor name must not be empty in provider '\(provider.name)'."
                    )
                }
                guard let type = monitor.resolvedType else {
                    throw .validationFailed(
                        "Monitor '\(monitor.name)' in provider '\(provider.name)' "
                        + "must specify exactly one type (http, tcp, betterstack, atlassian, statusio, incidentio)."
                    )
                }
                switch type {
                case .http:
                    if let http = monitor.http, http.url.isEmpty {
                        throw .validationFailed(
                            "HTTP monitor '\(monitor.name)' must have a non-empty URL."
                        )
                    }
                case .tcp:
                    if let tcp = monitor.tcp, tcp.host.isEmpty {
                        throw .validationFailed(
                            "TCP monitor '\(monitor.name)' must have a non-empty host."
                        )
                    }
                case .betterstack, .atlassian, .statusio, .incidentio:
                    break
                }
            }
        }
    }

    // MARK: - Default Config Creation

    /// Creates the default configuration directory and file if they don't exist.
    private func createDefaultConfig() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let defaultConfig = PulseConfiguration(
            version: "1.0",
            serviceProviders: [
                ServiceProvider(
                    name: "Example",
                    monitors: [
                        Monitor(
                            name: "HTTP Check",
                            http: HTTPMonitorConfig(
                                url: "https://example.com",
                                method: "GET",
                                expectedStatusCodes: [200]
                            )
                        )
                    ]
                ),
                ServiceProvider(
                    name: "Hacker News",
                    monitors: [
                        Monitor(
                            name: "Homepage",
                            http: HTTPMonitorConfig(
                                url: "https://news.ycombinator.com/",
                                method: "GET",
                                expectedStatusCodes: [200]
                            )
                        )
                    ]
                ),
                ServiceProvider(
                    name: "JSONPlaceholder",
                    monitors: [
                        Monitor(
                            name: "Posts API",
                            http: HTTPMonitorConfig(
                                url: "https://jsonplaceholder.typicode.com/posts/1",
                                method: "GET",
                                expectedStatusCodes: [200]
                            )
                        )
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(defaultConfig)
        try data.write(to: fileURL, options: .atomic)

        logger.info("Created default configuration at \(self.fileURL.path())")
    }

    // MARK: - File Watching

    /// Starts watching the configuration file for changes using an async stream
    /// backed by a file descriptor dispatch source.
    func startWatching() {
        guard watchTask == nil else { return }

        watchTask = Task { [fileURL, logger] in
            for await _ in Self.fileChangeStream(for: fileURL) {
                guard !Task.isCancelled else { break }
                logger.info("Configuration file changed, reloading…")
                await MainActor.run { [weak self] in
                    self?.load()
                }
            }
        }

        logger.info("Started watching configuration file for changes.")
    }

    /// Stops watching the configuration file.
    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        logger.info("Stopped watching configuration file.")
    }

    /// Creates an `AsyncStream` that yields whenever the file at `url` is modified.
    private static func fileChangeStream(for url: URL) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let path = url.path()
            let fd = open(path, O_EVTONLY)

            guard fd >= 0 else {
                continuation.finish()
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .global(qos: .utility)
            )

            source.setEventHandler {
                continuation.yield()
            }

            source.setCancelHandler {
                close(fd)
            }

            continuation.onTermination = { _ in
                source.cancel()
            }

            source.resume()
        }
    }
}
