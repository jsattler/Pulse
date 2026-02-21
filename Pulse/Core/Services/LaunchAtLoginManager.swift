import Foundation
import Observation
import ServiceManagement
import os

/// Manages the "Launch at Login" toggle using `SMAppService`.
@Observable
@MainActor
final class LaunchAtLoginManager {
    /// Whether the app is currently registered to launch at login.
    var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { setEnabled(newValue) }
    }

    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "LaunchAtLogin")

    /// Registers or unregisters the app for launch at login.
    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered for launch at login.")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered from launch at login.")
            }
        } catch {
            logger.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}
