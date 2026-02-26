import Foundation
import Sparkle

/// Wraps Sparkle's updater controller for use in SwiftUI.
///
/// This service owns the `SPUStandardUpdaterController` and exposes
/// observable state for whether the user can check for updates, and
/// a binding to the automatic-check preference managed by Sparkle.
///
/// A lightweight helper object is passed as `userDriverDelegate` to
/// declare support for gentle scheduled update reminders, which
/// prevents Sparkle's background-app warning about unnoticed alerts.
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

    /// Delegate that declares gentle reminder support.
    @ObservationIgnored
    private let driverDelegate = GentleUpdateReminderDelegate()

    /// KVO observation for `canCheckForUpdates`.
    @ObservationIgnored
    private var canCheckObservation: NSKeyValueObservation?

    // MARK: - Initialization

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: driverDelegate
        )

        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = value
            }
        }
    }

    // MARK: - Actions

    /// Triggers a user-initiated check for updates.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

// MARK: - Gentle Update Reminder Delegate

/// Minimal `SPUStandardUserDriverDelegate` that declares support for
/// gentle scheduled update reminders. This silences Sparkle's warning
/// for background (dockless) apps that schedule automatic update checks.
private final class GentleUpdateReminderDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
