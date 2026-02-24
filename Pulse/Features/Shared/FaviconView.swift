import AppKit
import SwiftUI

/// Displays a cached favicon for a website with a soft status-colored glow behind it.
///
/// Reads from a ``FaviconStore`` that fetches images once and caches them.
/// When no favicon is available, a plain white dot with the status-colored
/// glow is shown as a fallback.
struct FaviconView: View {
    /// The website URL whose domain is used to look up the cached favicon.
    var websiteURL: URL?

    /// The provider name used as a fallback key when `websiteURL` is nil.
    var providerName: String?

    /// The status color used for the glow effect behind the favicon.
    var statusColor: Color

    /// The diameter of the favicon image.
    var size: CGFloat = 18

    /// Whether to show the status-colored glow behind the favicon.
    var showsGlow: Bool = true

    /// The store that holds cached favicon images.
    var faviconStore: FaviconStore?

    private var cachedImage: NSImage? {
        if let image = faviconStore?.image(for: websiteURL) {
            return image
        }
        if let name = providerName {
            return faviconStore?.image(forProvider: name)
        }
        return nil
    }

    var body: some View {
        if let nsImage = cachedImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .background { if showsGlow { statusGlow } }
        } else {
            Circle()
                .fill(.white)
                .frame(width: size * 0.4, height: size * 0.4)
                .frame(width: size, height: size)
                .background { if showsGlow { statusGlow } }
        }
    }

    private var statusGlow: some View {
        Circle()
            .fill(statusColor.opacity(0.5))
            .frame(width: size + 6, height: size + 6)
            .blur(radius: 6)
    }
}
