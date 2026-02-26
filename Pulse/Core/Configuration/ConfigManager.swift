import Foundation
import Observation
import os

/// Manages loading, validating, and watching the Pulse configuration file.
///
/// The default configuration path is `~/.config/pulse/config.json`.
@Observable
@MainActor
final class ConfigManager {
    /// The currently loaded configuration, or `nil` if not yet loaded.
    private(set) var configuration: PulseConfiguration?

    /// The last error encountered during loading.
    private(set) var lastError: ConfigurationError?

    /// Whether the configuration has been loaded successfully at least once.
    var isLoaded: Bool { configuration != nil }

    /// Called on the main actor after a configuration is successfully loaded.
    @ObservationIgnored var onChange: ((PulseConfiguration) -> Void)?

    private(set) var fileURL: URL
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "ConfigManager")
    @ObservationIgnored nonisolated(unsafe) private var watchTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultConfigURL
    }

    deinit {
        watchTask?.cancel()
    }

    // MARK: - Default Path

    /// Default configuration file location: `~/.config/pulse/config.json`.
    static var defaultConfigURL: URL {
        URL.homeDirectory
            .appending(path: ".config/pulse/config.json")
    }

    /// The URL of the directory containing the configuration file.
    var configDirectoryURL: URL {
        fileURL.deletingLastPathComponent()
    }

    // MARK: - Saving

    /// Writes the current configuration to disk as pretty-printed JSON.
    func save() throws {
        guard let configuration else {
            throw ConfigurationError.validationFailed("No configuration loaded to save.")
        }

        let directory = configDirectoryURL
        if !FileManager.default.fileExists(atPath: directory.path()) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
        logger.info("Configuration saved to \(self.fileURL.path())")
    }

    // MARK: - Service Provider CRUD

    /// Adds a new service provider and saves.
    func addServiceProvider(_ provider: ServiceProvider) throws {
        var config = configuration ?? PulseConfiguration(version: "1.0", serviceProviders: [])
        config.serviceProviders.append(provider)
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    /// Updates an existing service provider by matching its original name, then saves.
    func updateServiceProvider(originalName: String, with updated: ServiceProvider) throws {
        guard var config = configuration else { return }
        guard let index = config.serviceProviders.firstIndex(where: { $0.name == originalName })
        else {
            throw ConfigurationError.validationFailed(
                "Service provider '\(originalName)' not found.")
        }
        config.serviceProviders[index] = updated
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    /// Removes a service provider by name and saves.
    func removeServiceProvider(named name: String) throws {
        guard var config = configuration else { return }
        config.serviceProviders.removeAll { $0.name == name }
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    // MARK: - Monitor CRUD

    /// Adds a monitor to a service provider and saves.
    func addMonitor(_ monitor: Monitor, toProviderNamed providerName: String) throws {
        guard var config = configuration else { return }
        guard let index = config.serviceProviders.firstIndex(where: { $0.name == providerName })
        else {
            throw ConfigurationError.validationFailed(
                "Service provider '\(providerName)' not found.")
        }
        config.serviceProviders[index].monitors.append(monitor)
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    /// Updates an existing monitor within a service provider and saves.
    func updateMonitor(
        originalName: String,
        with updated: Monitor,
        inProviderNamed providerName: String
    ) throws {
        guard var config = configuration else { return }
        guard
            let providerIndex = config.serviceProviders.firstIndex(where: {
                $0.name == providerName
            })
        else {
            throw ConfigurationError.validationFailed(
                "Service provider '\(providerName)' not found.")
        }
        guard
            let monitorIndex = config.serviceProviders[providerIndex].monitors.firstIndex(where: {
                $0.name == originalName
            })
        else {
            throw ConfigurationError.validationFailed(
                "Monitor '\(originalName)' not found in provider '\(providerName)'.")
        }
        config.serviceProviders[providerIndex].monitors[monitorIndex] = updated
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    /// Removes a monitor from a service provider and saves.
    func removeMonitor(named monitorName: String, fromProviderNamed providerName: String) throws {
        guard var config = configuration else { return }
        guard
            let providerIndex = config.serviceProviders.firstIndex(where: {
                $0.name == providerName
            })
        else {
            throw ConfigurationError.validationFailed(
                "Service provider '\(providerName)' not found.")
        }
        config.serviceProviders[providerIndex].monitors.removeAll { $0.name == monitorName }
        try validate(config)
        configuration = config
        try save()
        onChange?(config)
    }

    // MARK: - Import

    /// Imports a configuration from a user-selected file, replacing the current config.
    func importConfig(from sourceURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let decoded = try JSONDecoder().decode(PulseConfiguration.self, from: data)
        try validate(decoded)

        // Write imported config to the standard location.
        let directory = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path()) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: fileURL, options: .atomic)

        configuration = decoded
        lastError = nil
        logger.info("Configuration imported from \(sourceURL.path())")
        onChange?(decoded)
    }

    // MARK: - Loading

    /// Loads configuration from disk. If no file exists, configuration remains empty.
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            logger.info("No configuration file found at \(self.fileURL.path()), starting empty.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(PulseConfiguration.self, from: data)
            try validate(decoded)

            configuration = decoded
            lastError = nil
            logger.info("Configuration loaded successfully from \(self.fileURL.path())")
            onChange?(decoded)
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
