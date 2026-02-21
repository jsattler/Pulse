import SwiftUI

@main
struct PulseApp: App {
    @State private var configManager = ConfigManager()
    @State private var monitorEngine = MonitorEngine()
    @State private var notchController = NotchController()

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
            SettingsView()
        }
    }

    init() {
        configManager.load()
        configManager.startWatching()

        // Capture locals so the Task closure doesn't capture `self`
        // (capturing `self` in App.init is not allowed with @State).
        let configManager = configManager
        let monitorEngine = monitorEngine
        let notchController = notchController

        // Hop to MainActor to read observable properties without subscribing
        // the scene body — if done inside body{} SwiftUI re-evaluates the
        // entire scene on every state change, causing panel flicker.
        Task { @MainActor in
            if let config = configManager.configuration {
                monitorEngine.apply(config)
            }
            notchController.monitorEngine = monitorEngine
            notchController.configuration = configManager.configuration
            notchController.show()
        }
    }
}
