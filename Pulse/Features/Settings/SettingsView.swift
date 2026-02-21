import SwiftUI
import ServiceManagement

/// The settings window for Pulse.
struct SettingsView: View {
    @State private var launchAtLoginManager = LaunchAtLoginManager()

    var body: some View {
        Form {
            Toggle(
                "Launch at Login",
                isOn: Bindable(launchAtLoginManager).isEnabled
            )
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
