import SwiftUI
import ServiceManagement

/// The settings window for Pulse.
struct SettingsView: View {
    var configManager: ConfigManager
    var glowSettings: GlowSettings
    var notificationManager: NotificationManager
    var faviconStore: FaviconStore?

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView(glowSettings: glowSettings, notificationManager: notificationManager)
            }

            Tab("Services", systemImage: "server.rack") {
                ServicesSettingsView(configManager: configManager, faviconStore: faviconStore)
            }
        }
        .frame(width: 500, height: 400)
    }
}

/// General settings tab containing launch-at-login, notch glow, and notification options.
struct GeneralSettingsView: View {
    @State private var launchAtLoginManager = LaunchAtLoginManager()
    var glowSettings: GlowSettings
    var notificationManager: NotificationManager

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch at Login",
                    isOn: Bindable(launchAtLoginManager).isEnabled
                )
            }

            Section("Notch Glow") {
                Picker("Hide Glow", selection: Bindable(glowSettings).hideGlow) {
                    ForEach(GlowCondition.allCases) { condition in
                        Text(condition.rawValue).tag(condition)
                    }
                }

                Picker("Disable Pulse Effect", selection: Bindable(glowSettings).disablePulse) {
                    ForEach(GlowCondition.allCases) { condition in
                        Text(condition.rawValue).tag(condition)
                    }
                }

                Slider(value: Bindable(glowSettings).glowSize, in: 0.5...2.0) {
                    Text("Glow Size")
                } minimumValueLabel: {
                    Text("S")
                } maximumValueLabel: {
                    Text("L")
                }
            }

            Section("Notifications") {
                Toggle(
                    "Enable Notifications",
                    isOn: Bindable(notificationManager).isEnabled
                )
                .tint(.accentColor)

                if notificationManager.isEnabled {
                    Text("Status Events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(NotificationManager.selectableStatuses, id: \.self) { status in
                        Toggle(status.label, isOn: statusBinding(for: status))
                            .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func statusBinding(for status: MonitorStatus) -> Binding<Bool> {
        Binding(
            get: { notificationManager.notifiableStatuses.contains(status) },
            set: { isOn in
                if isOn {
                    notificationManager.notifiableStatuses.insert(status)
                } else {
                    notificationManager.notifiableStatuses.remove(status)
                }
            }
        )
    }
}
