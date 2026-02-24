import SwiftUI

/// Sheet form for adding or editing a single monitor within a service provider.
///
/// The form adapts its fields based on the selected monitor type:
/// - HTTP: URL, method, expected status codes, max latency, check frequency, failure threshold
/// - Better Stack / Atlassian: Status page URL only (format is always JSON)
struct MonitorDetailView: View {
    let mode: Mode
    let onSave: (Monitor) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Common fields
    @State private var name: String = ""
    @State private var monitorType: MonitorType = .http

    // HTTP fields
    @State private var httpURL: String = ""
    @State private var httpMethod: String = "GET"
    @State private var expectedStatusCodes: String = "200"
    @State private var maxLatency: String = ""
    @State private var checkFrequency: String = ""
    @State private var failureThreshold: String = ""

    // Status page fields
    @State private var statusPageURL: String = ""

    enum Mode {
        case add
        case edit(Monitor)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }

        switch monitorType {
        case .http:
            return !httpURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .betterstack, .atlassian:
            return !statusPageURL.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return false
        }
    }

    var body: some View {
        Form {
            Section("Monitor") {
                TextField("Name", text: $name)

                Picker("Type", selection: $monitorType) {
                    ForEach(MonitorType.implemented) { type in
                        Text(type.label).tag(type)
                    }
                }
            }

            switch monitorType {
            case .http:
                HTTPMonitorSection(
                    url: $httpURL,
                    method: $httpMethod,
                    expectedStatusCodes: $expectedStatusCodes,
                    maxLatency: $maxLatency,
                    checkFrequency: $checkFrequency,
                    failureThreshold: $failureThreshold
                )
            case .betterstack, .atlassian:
                StatusPageMonitorSection(url: $statusPageURL)
            default:
                EmptyView()
            }

            if isEditing, let onDelete {
                Section {
                    Button("Delete Monitor", role: .destructive) {
                        onDelete()
                        dismiss()
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
        .frame(minWidth: 380, minHeight: 250)
        .onAppear { populateFromExisting() }
    }

    // MARK: - Populate

    private func populateFromExisting() {
        guard case .edit(let monitor) = mode else { return }

        name = monitor.name

        if let type = monitor.resolvedType {
            monitorType = type
        }

        if let http = monitor.http {
            httpURL = http.url
            httpMethod = http.method ?? "GET"
            expectedStatusCodes = http.expectedStatusCodes?
                .map(String.init).joined(separator: ",") ?? "200"
            maxLatency = http.maxLatency.map(String.init) ?? ""
            checkFrequency = http.checkFrequency.map(String.init) ?? ""
            failureThreshold = http.failureThreshold.map(String.init) ?? ""
        }

        if let config = monitor.betterstack ?? monitor.atlassian {
            statusPageURL = config.url
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        var monitor = Monitor(name: trimmedName)

        switch monitorType {
        case .http:
            let codes = expectedStatusCodes
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

            monitor.http = HTTPMonitorConfig(
                url: httpURL.trimmingCharacters(in: .whitespaces),
                method: httpMethod,
                checkFrequency: Int(checkFrequency),
                expectedStatusCodes: codes.isEmpty ? nil : codes,
                maxLatency: Int(maxLatency),
                failureThreshold: Int(failureThreshold)
            )

        case .betterstack:
            monitor.betterstack = StatusPageMonitorConfig(
                url: statusPageURL.trimmingCharacters(in: .whitespaces),
                format: "json"
            )

        case .atlassian:
            monitor.atlassian = StatusPageMonitorConfig(
                url: statusPageURL.trimmingCharacters(in: .whitespaces),
                format: "json"
            )

        default:
            break
        }

        onSave(monitor)
        dismiss()
    }
}

// MARK: - HTTP Monitor Section

/// Form section with fields specific to HTTP monitors.
struct HTTPMonitorSection: View {
    @Binding var url: String
    @Binding var method: String
    @Binding var expectedStatusCodes: String
    @Binding var maxLatency: String
    @Binding var checkFrequency: String
    @Binding var failureThreshold: String

    var body: some View {
        Section("HTTP") {
            TextField("URL", text: $url)

            Picker("Method", selection: $method) {
                Text("GET").tag("GET")
                Text("HEAD").tag("HEAD")
                Text("POST").tag("POST")
            }

            TextField("Expected Status Codes", text: $expectedStatusCodes)
                .help("Comma-separated, e.g. 200,201")

            TextField("Max Latency (ms)", text: $maxLatency)

            TextField("Check Frequency (seconds)", text: $checkFrequency)

            TextField("Failure Threshold", text: $failureThreshold)
        }
    }
}

// MARK: - Status Page Monitor Section

/// Form section with fields specific to status page monitors.
struct StatusPageMonitorSection: View {
    @Binding var url: String

    var body: some View {
        Section("Status Page") {
            TextField("URL", text: $url)
        }
    }
}
