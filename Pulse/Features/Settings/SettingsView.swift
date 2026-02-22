import SwiftUI
import ServiceManagement

/// The settings window for Pulse.
struct SettingsView: View {
    @State private var launchAtLoginManager = LaunchAtLoginManager()
    var glowSettings: GlowSettings

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
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 240)
    }
}
