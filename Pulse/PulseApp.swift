import SwiftUI

@main
struct PulseApp: App {
    @State private var configManager = ConfigManager()
    @State private var monitorEngine = MonitorEngine()
    @State private var notchController = NotchController()
    @State private var glowSettings = GlowSettings()
    @State private var faviconStore = FaviconStore()
    @State private var notificationManager = NotificationManager()
    @State private var updaterManager = UpdaterManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                configManager: configManager,
                monitorEngine: monitorEngine,
                faviconStore: faviconStore
            )
        } label: {
            MenuBarStatusDot(monitorEngine: monitorEngine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                configManager: configManager,
                glowSettings: glowSettings,
                notificationManager: notificationManager,
                updaterManager: updaterManager,
                faviconStore: faviconStore
            )
        }
    }

    init() {
        // Capture locals so the Task closure doesn't capture `self`
        // (capturing `self` in App.init is not allowed with @State).
        let configManager = configManager
        let monitorEngine = monitorEngine
        let notchController = notchController
        let glowSettings = glowSettings
        let faviconStore = faviconStore
        let notificationManager = notificationManager

        monitorEngine.faviconStore = faviconStore

        // Send a notification when a monitor transitions to a non-operational status,
        // unless the provider is silenced or notifications are disabled.
        monitorEngine.onStatusChange = { providerName, displayName, _, newStatus in
            guard notificationManager.isEnabled else { return }
            guard !glowSettings.isSilenced(providerName) else { return }
            guard notificationManager.notifiableStatuses.contains(newStatus) else { return }
            notificationManager.sendStatusNotification(
                providerName: providerName,
                monitorDisplayName: displayName,
                status: newStatus
            )
        }

        notificationManager.requestPermission()

        // Re-apply configuration whenever the file watcher reloads it.
        configManager.onChange = { (config: PulseConfiguration) in
            monitorEngine.apply(config)
            notchController.configuration = config
        }

        configManager.load()
        configManager.startWatching()

        // Hop to MainActor to read observable properties without subscribing
        // the scene body — if done inside body{} SwiftUI re-evaluates the
        // entire scene on every state change, causing panel flicker.
        Task { @MainActor in
            notchController.monitorEngine = monitorEngine
            notchController.glowSettings = glowSettings
            notchController.faviconStore = faviconStore
            notchController.show()
        }
    }
}
