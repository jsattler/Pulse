import AppKit
import Observation
import os

/// Fetches and caches favicons for service providers.
///
/// Images are fetched once per domain via the Google Favicon API and kept
/// in memory for the lifetime of the app. Duplicate requests for the same
/// domain are coalesced.
@Observable
@MainActor
final class FaviconStore {
    /// Cached images keyed by website host.
    private(set) var imagesByHost: [String: NSImage] = [:]

    /// Maps provider names to the host used for their favicon, so views
    /// that only know the provider name can look up the cached image.
    private(set) var hostByProvider: [String: String] = [:]

    /// Hosts that are currently being fetched or have already been attempted.
    @ObservationIgnored private var requestedHosts: Set<String> = []

    @ObservationIgnored private let logger = Logger(
        subsystem: "com.sattlerjoshua.Pulse",
        category: "FaviconStore"
    )

    /// Ensures a favicon is fetched for the given website URL.
    ///
    /// The provider name is recorded so views can look up favicons by
    /// provider name when the config doesn't include a `websiteURL`.
    /// Does nothing if the host was already fetched or is in flight.
    func ensureFavicon(for websiteURL: URL, providerName: String) {
        guard let host = websiteURL.host() else { return }
        hostByProvider[providerName] = host
        guard !requestedHosts.contains(host) else { return }
        requestedHosts.insert(host)

        Task {
            if let image = await fetchFavicon(host: host) {
                imagesByHost[host] = image
            } else {
                logger.debug("Failed to fetch favicon for \(host)")
            }
        }
    }

    /// Returns the cached image for a website URL, if available.
    func image(for websiteURL: URL?) -> NSImage? {
        guard let host = websiteURL?.host() else { return nil }
        return imagesByHost[host]
    }

    /// Returns the cached image for a provider name, if available.
    func image(forProvider name: String) -> NSImage? {
        guard let host = hostByProvider[name] else { return nil }
        return imagesByHost[host]
    }

    // MARK: - Private

    /// Fetches a favicon on a background thread using `Data(contentsOf:)`.
    ///
    /// `URLSession` is avoided entirely because its internal HTTP/3 QUIC
    /// probing produces `nw_connection` warnings that cannot be suppressed
    /// via public API. A detached task is used to move the synchronous I/O
    /// off the main actor.
    private nonisolated func fetchFavicon(host: String) async -> NSImage? {
        guard let url = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            return nil
        }

        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data),
                  image.isValid else {
                return nil as NSImage?
            }
            return image
        }.value
    }
}
