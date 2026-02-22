import SwiftUI

@main
struct PulseApp: App {
    @State private var configManager = ConfigManager()
    @State private var monitorEngine = MonitorEngine()
    @State private var notchController = NotchController()
    @State private var glowSettings = GlowSettings()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                configManager: configManager,
                monitorEngine: monitorEngine
            )
        } label: {
            MenuBarStatusDot(monitorEngine: monitorEngine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(glowSettings: glowSettings)
        }
    }

    init() {
        // Capture locals so the Task closure doesn't capture `self`
        // (capturing `self` in App.init is not allowed with @State).
        let configManager = configManager
        let monitorEngine = monitorEngine
        let notchController = notchController
        let glowSettings = glowSettings

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
            notchController.show()
        }
    }
}
