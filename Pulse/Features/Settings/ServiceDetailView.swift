import SwiftUI

/// Sheet form for adding or editing a service provider and its monitors.
///
/// In add mode, the user fills in the name and adds monitors, then saves.
/// In edit mode, the form is pre-populated with existing data.
struct ServiceDetailView: View {
    var configManager: ConfigManager
    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var websiteURL: String = ""
    @State private var monitors: [Monitor] = []
    @State private var isAddingMonitor = false
    @State private var editingMonitorIndex: Int?
    @State private var errorMessage: String?

    enum Mode {
        case add
        case edit(providerName: String)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !monitors.isEmpty
    }

    var body: some View {
        Form {
            Section("Service") {
                TextField("Name", text: $name, prompt: Text("e.g. Anthropic"))
                TextField("Website URL (Optional)", text: $websiteURL, prompt: Text("e.g. https://anthropic.com"))
                    .help("Used to display a favicon. Auto-derived for status page monitors.")
            }

            Section {
                if monitors.isEmpty {
                    Text("No monitors added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monitors.indices, id: \.self) { index in
                        Button {
                            editingMonitorIndex = index
                        } label: {
                            SettingsMonitorRow(monitor: monitors[index])
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                monitors.remove(at: index)
                            }
                        }
                    }
                }
            } header: {
                Text("Monitors")
            } footer: {
                Button("Add Monitor", systemImage: "plus") {
                    isAddingMonitor = true
                }
                .buttonStyle(.bordered)
            }

            if isEditing {
                Section {
                    Button("Delete Service", role: .destructive) {
                        deleteService()
                    }
                }
            }

            Section {
                HStack {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $isAddingMonitor) {
            MonitorDetailView(mode: .add) { newMonitor in
                monitors.append(newMonitor)
            }
        }
        .sheet(item: editingMonitorBinding) { monitor in
            MonitorDetailView(mode: .edit(monitor), onSave: { updated in
                if let index = editingMonitorIndex {
                    monitors[index] = updated
                }
            }, onDelete: {
                if let index = editingMonitorIndex,
                   monitors.indices.contains(index) {
                    monitors.remove(at: index)
                }
            })
        }
        .alert("Error", isPresented: showErrorBinding) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear { populateFromExisting() }
    }

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    /// Creates a binding that maps `editingMonitorIndex` to the corresponding `Monitor`.
    private var editingMonitorBinding: Binding<Monitor?> {
        Binding(
            get: {
                guard let index = editingMonitorIndex,
                      monitors.indices.contains(index) else { return nil }
                return monitors[index]
            },
            set: { newValue in
                if newValue == nil { editingMonitorIndex = nil }
            }
        )
    }

    private func populateFromExisting() {
        guard case .edit(let providerName) = mode,
              let provider = configManager.configuration?.serviceProviders
                  .first(where: { $0.name == providerName })
        else { return }
        name = provider.name
        websiteURL = provider.websiteURL ?? ""
        monitors = provider.monitors
    }

    private func deleteService() {
        guard case .edit(let providerName) = mode else { return }
        do {
            try configManager.removeServiceProvider(named: providerName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let trimmedURL = websiteURL.trimmingCharacters(in: .whitespaces)
        let provider = ServiceProvider(
            name: name.trimmingCharacters(in: .whitespaces),
            websiteURL: trimmedURL.isEmpty ? nil : trimmedURL,
            monitors: monitors
        )

        do {
            switch mode {
            case .add:
                try configManager.addServiceProvider(provider)
            case .edit(let originalName):
                try configManager.updateServiceProvider(
                    originalName: originalName,
                    with: provider
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Monitor Row

/// A single row in the monitors list showing the monitor name and type.
struct SettingsMonitorRow: View {
    let monitor: Monitor

    var body: some View {
        VStack(alignment: .leading) {
            Text(monitor.name)
            if let type = monitor.resolvedType {
                Text(type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
