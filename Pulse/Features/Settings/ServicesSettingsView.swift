import SwiftUI

/// Lists all configured service providers with add, edit, and delete support.
///
/// Presents add and edit forms as sheets to avoid toolbar conflicts with the
/// settings `TabView`.
struct ServicesSettingsView: View {
    var configManager: ConfigManager
    var faviconStore: FaviconStore?

    @State private var editingProvider: ServiceProvider?
    @State private var isAddingProvider = false
    @State private var errorMessage: String?

    private var providers: [ServiceProvider] {
        configManager.configuration?.serviceProviders ?? []
    }

    var body: some View {
        Form {
            Section {
                if providers.isEmpty {
                    Text("No services configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(providers) { provider in
                        Button {
                            editingProvider = provider
                        } label: {
                            SettingsServiceRow(provider: provider, faviconStore: faviconStore)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteProvider(named: provider.name)
                            }
                        }
                    }
                }
            } header: {
                Text("Services")
            } footer: {
                HStack {
                    Button("Add Service", systemImage: "plus") {
                        isAddingProvider = true
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button("Open in Finder", systemImage: "folder") {
                        let fileManager = FileManager.default
                        let directory = configManager.configDirectoryURL

                        if !fileManager.fileExists(atPath: directory.path()) {
                            try? fileManager.createDirectory(
                                at: directory, withIntermediateDirectories: true)
                        }

                        if fileManager.fileExists(atPath: configManager.fileURL.path()) {
                            NSWorkspace.shared.selectFile(
                                configManager.fileURL.path(),
                                inFileViewerRootedAtPath: directory.path()
                            )
                        } else {
                            NSWorkspace.shared.open(directory)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isAddingProvider) {
            ServiceDetailView(configManager: configManager, mode: .add)
        }
        .sheet(item: $editingProvider) { provider in
            ServiceDetailView(
                configManager: configManager,
                mode: .edit(providerName: provider.name)
            )
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func deleteProvider(named name: String) {
        do {
            try configManager.removeServiceProvider(named: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Service Provider Row

/// A single row in the services list showing the provider name and monitor count.
struct SettingsServiceRow: View {
    let provider: ServiceProvider
    var faviconStore: FaviconStore?

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(
                websiteURL: provider.websiteURL.flatMap { URL(string: $0) },
                providerName: provider.name,
                statusColor: .secondary,
                size: 18,
                showsGlow: false,
                faviconStore: faviconStore
            )

            VStack(alignment: .leading) {
                Text(provider.name)
                Text(monitorSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monitorSummary: String {
        let count = provider.monitors.count
        return count == 1 ? "1 monitor" : "\(count) monitors"
    }
}
