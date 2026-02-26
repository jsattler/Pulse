import Foundation
import Sparkle

/// Wraps Sparkle's updater controller for use in SwiftUI.
///
/// This service owns the `SPUStandardUpdaterController` and exposes
/// observable state for whether the user can check for updates, and
/// a binding to the automatic-check preference managed by Sparkle.
@MainActor
@Observable
final class UpdaterManager {

    // MARK: - Properties

    /// Whether the updater is currently able to check for updates.
    private(set) var canCheckForUpdates = false

    /// Whether Sparkle should automatically check for updates.
    /// This directly reads/writes Sparkle's own user-defaults-backed property.
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// The underlying Sparkle updater controller.
    private let controller: SPUStandardUpdaterController

    /// KVO observation for `canCheckForUpdates`.
    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    // MARK: - Initialization

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    // MARK: - Actions

    /// Triggers a user-initiated check for updates.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
