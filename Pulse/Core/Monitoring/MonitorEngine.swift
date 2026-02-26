import Foundation
import Observation
import os

/// Owns all live monitor state, creates providers from configuration,
/// and runs independent polling tasks for each monitor.
@Observable
@MainActor
final class MonitorEngine {
    /// Live state for every runtime monitor, keyed by provider name.
    /// Each provider maps to an ordered array of `MonitorState` entries,
    /// including expanded components from aggregated providers.
    private(set) var statesByProvider: [String: [MonitorState]] = [:]

    /// Website URLs per provider, from the config's `websiteURL` or
    /// auto-discovered from status page API responses.
    private(set) var websiteURLsByProvider: [String: URL] = [:]

    /// Status page URLs per provider, derived from the first status page
    /// monitor's configuration URL when the provider uses a status page type.
    private(set) var statusPageURLsByProvider: [String: URL] = [:]

    /// Favicon store for triggering fetches when website URLs are resolved.
    var faviconStore: FaviconStore?

    /// Called when a monitor transitions between statuses.
    /// Parameters: provider name, monitor display name, old status, new status.
    @ObservationIgnored
    var onStatusChange: ((_ providerName: String, _ displayName: String, _ oldStatus: MonitorStatus, _ newStatus: MonitorStatus) -> Void)?

    /// The worst status across all monitors.
    var aggregateStatus: MonitorStatus {
        let allStates = statesByProvider.values.flatMap { $0 }
        guard !allStates.isEmpty else { return .unknown }
        return allStates.map(\.status).max() ?? .unknown

    }

    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "MonitorEngine")

    /// Config-level key for a polling task: provider name + monitor name.
    private struct PollKey: Hashable {
        var providerName: String
        var monitorName: String
    }

    /// Active polling tasks, keyed by config-level monitor identity.
    @ObservationIgnored private var pollTasks: [PollKey: Task<Void, Never>] = [:]

    /// The configuration snapshot currently being monitored.
    @ObservationIgnored private var activeConfig: PulseConfiguration?

    // MARK: - Public API

    /// Applies a new configuration. Diffs against the current config and
    /// starts/stops/restarts polling tasks as needed.
    func apply(_ config: PulseConfiguration) {
        let oldKeys = Set(pollTasks.keys)
        var newKeys = Set<PollKey>()

        for provider in config.serviceProviders {
            // Seed website URL from config.
            if let urlString = provider.websiteURL,
               let url = URL(string: urlString) {
                websiteURLsByProvider[provider.name] = url
                faviconStore?.ensureFavicon(for: url, providerName: provider.name)
            }

            // Derive status page URL from the first status page monitor.
            if statusPageURLsByProvider[provider.name] == nil {
                for monitor in provider.monitors {
                    let urlString: String? = monitor.atlassian?.url
                        ?? monitor.betterstack?.url
                        ?? monitor.statusio?.url
                        ?? monitor.incidentio?.url
                    if let urlString, let url = URL(string: urlString) {
                        statusPageURLsByProvider[provider.name] = url
                        break
                    }
                }
            }

            for monitor in provider.monitors {
                let key = PollKey(providerName: provider.name, monitorName: monitor.name)
                newKeys.insert(key)

                if oldKeys.contains(key), configUnchanged(provider: provider.name, monitor: monitor) {
                    // Monitor config hasn't changed — keep existing task.
                    continue
                }

                // Cancel existing task if the config changed.
                pollTasks[key]?.cancel()

                // Initialize state and start polling.
                startPolling(provider: provider, monitor: monitor, key: key)
            }
        }

        // Cancel tasks for monitors that were removed.
        for removedKey in oldKeys.subtracting(newKeys) {
            pollTasks[removedKey]?.cancel()
            pollTasks[removedKey] = nil

            // Remove state entries that belonged to this monitor.
            statesByProvider[removedKey.providerName]?.removeAll { state in
                state.id.monitorName == removedKey.monitorName
            }
            // Clean up empty provider arrays.
            if statesByProvider[removedKey.providerName]?.isEmpty == true {
                statesByProvider[removedKey.providerName] = nil
            }
        }

        // Clean up URL entries for removed providers.
        let activeProviderNames = Set(config.serviceProviders.map(\.name))
        for name in websiteURLsByProvider.keys where !activeProviderNames.contains(name) {
            websiteURLsByProvider[name] = nil
        }
        for name in statusPageURLsByProvider.keys where !activeProviderNames.contains(name) {
            statusPageURLsByProvider[name] = nil
        }

        activeConfig = config
    }

    // MARK: - Polling

    private func startPolling(provider: ServiceProvider, monitor: Monitor, key: PollKey) {
        guard let monitorType = monitor.resolvedType else {
            logger.warning("Monitor '\(monitor.name)' in '\(provider.name)' has no resolved type, skipping.")
            return
        }

        let frequency = checkFrequency(for: monitor)

        switch monitorType {
        case .http:
            guard let config = monitor.http else { return }
            let httpProvider = HTTPMonitorProvider(config: config)
            initializeSingleState(key: key, monitorType: monitorType)
            pollTasks[key] = Task { [weak self] in
                await self?.pollSingle(provider: httpProvider, key: key, frequency: frequency)
            }

        case .betterstack:
            guard let config = monitor.betterstack else { return }
            let bsProvider = BetterStackMonitorProvider(config: config)
            pollTasks[key] = Task { [weak self] in
                await self?.pollAggregated(provider: bsProvider, key: key, monitorType: monitorType, frequency: frequency)
            }

        case .atlassian:
            guard let config = monitor.atlassian else { return }
            let atlassianProvider = AtlassianMonitorProvider(config: config)
            pollTasks[key] = Task { [weak self] in
                await self?.pollAggregated(provider: atlassianProvider, key: key, monitorType: monitorType, frequency: frequency)
            }

        case .tcp, .statusio, .incidentio:
            // Not yet implemented — show unknown state.
            initializeSingleState(key: key, monitorType: monitorType)
            logger.info("Monitor type '\(monitorType.rawValue)' not yet implemented for '\(monitor.name)'.")
        }
    }

    /// Polling loop for single-result providers.
    private func pollSingle(
        provider: some MonitorProvider,
        key: PollKey,
        frequency: Duration
    ) async {
        while !Task.isCancelled {
            let result: CheckResult
            do {
                result = try await provider.check()
            } catch {
                result = CheckResult(
                    status: .downtime,
                    timestamp: .now,
                    message: error.localizedDescription
                )
            }

            await MainActor.run { [weak self] in
                self?.updateSingleState(key: key, result: result)
            }

            try? await Task.sleep(for: frequency)
        }
    }

    /// Polling loop for aggregated providers (status pages).
    private func pollAggregated(
        provider: some AggregatedMonitorProvider,
        key: PollKey,
        monitorType: MonitorType,
        frequency: Duration
    ) async {
        while !Task.isCancelled {
            let aggregated: AggregatedCheckResult
            do {
                aggregated = try await provider.check()
            } catch {
                // On failure, set a single "downtime" entry.
                let errorResult = ComponentCheckResult(
                    componentName: key.monitorName,
                    result: CheckResult(
                        status: .downtime,
                        timestamp: .now,
                        message: error.localizedDescription
                    )
                )
                aggregated = AggregatedCheckResult(components: [errorResult])
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                updateAggregatedState(key: key, monitorType: monitorType, results: aggregated.components)

                // Auto-discover website URL when the config doesn't provide one.
                if websiteURLsByProvider[key.providerName] == nil,
                   let url = aggregated.websiteURL {
                    websiteURLsByProvider[key.providerName] = url
                    faviconStore?.ensureFavicon(for: url, providerName: key.providerName)
                }
            }

            try? await Task.sleep(for: frequency)
        }
    }

    // MARK: - State Management

    private func initializeSingleState(key: PollKey, monitorType: MonitorType) {
        let stateID = MonitorStateID(
            providerName: key.providerName,
            monitorName: key.monitorName
        )
        let state = MonitorState(
            id: stateID,
            displayName: key.monitorName,
            status: .unknown,
            consecutiveFailures: 0,
            monitorType: monitorType
        )
        upsertState(state, forProvider: key.providerName)
    }

    private func updateSingleState(key: PollKey, result: CheckResult) {
        let stateID = MonitorStateID(
            providerName: key.providerName,
            monitorName: key.monitorName
        )

        guard var states = statesByProvider[key.providerName],
              let index = states.firstIndex(where: { $0.id == stateID }) else { return }

        let oldStatus = states[index].status

        states[index].status = result.status
        states[index].lastResult = result
        appendRecentResult(result, at: &states[index])
        if result.status == .operational {
            states[index].consecutiveFailures = 0
        } else {
            states[index].consecutiveFailures += 1
        }

        statesByProvider[key.providerName] = states

        if oldStatus != result.status {
            onStatusChange?(key.providerName, states[index].displayName, oldStatus, result.status)
        }
    }

    private func updateAggregatedState(
        key: PollKey,
        monitorType: MonitorType,
        results: [ComponentCheckResult]
    ) {
        // Capture existing states before removal so we can carry over history.
        let previousStates = statesByProvider[key.providerName]?.filter { $0.id.monitorName == key.monitorName } ?? []

        // Remove old component entries for this config monitor.
        statesByProvider[key.providerName]?.removeAll { $0.id.monitorName == key.monitorName }

        // Insert one state per component.
        for component in results {
            let stateID = MonitorStateID(
                providerName: key.providerName,
                monitorName: key.monitorName,
                componentName: component.componentName
            )

            let existing = previousStates.first { $0.id == stateID }
            let failures: Int
            if component.result.status == .operational {
                failures = 0
            } else {
                failures = (existing?.consecutiveFailures ?? 0) + 1
            }

            var recentResults = existing?.recentResults ?? []
            recentResults.append(component.result)
            if recentResults.count > MonitorState.maxRecentResults {
                recentResults.removeFirst(recentResults.count - MonitorState.maxRecentResults)
            }

            let state = MonitorState(
                id: stateID,
                displayName: component.componentName,
                status: component.result.status,
                lastResult: component.result,
                recentResults: recentResults,
                consecutiveFailures: failures,
                monitorType: monitorType
            )
            upsertState(state, forProvider: key.providerName)

            let oldStatus = existing?.status ?? .unknown
            if oldStatus != component.result.status {
                onStatusChange?(key.providerName, component.componentName, oldStatus, component.result.status)
            }
        }
    }

    private func appendRecentResult(_ result: CheckResult, at state: inout MonitorState) {
        state.recentResults.append(result)
        if state.recentResults.count > MonitorState.maxRecentResults {
            state.recentResults.removeFirst(state.recentResults.count - MonitorState.maxRecentResults)
        }
    }

    private func upsertState(_ state: MonitorState, forProvider providerName: String) {
        var states = statesByProvider[providerName, default: []]
        if let index = states.firstIndex(where: { $0.id == state.id }) {
            states[index] = state
        } else {
            states.append(state)
        }
        statesByProvider[providerName] = states
    }

    // MARK: - Helpers

    /// Returns the check frequency for a monitor, with a sensible default.
    private func checkFrequency(for monitor: Monitor) -> Duration {
        let seconds: Int
        if let http = monitor.http {
            seconds = http.checkFrequency ?? 30
        } else if let tcp = monitor.tcp {
            seconds = tcp.checkFrequency ?? 30
        } else {
            // Status pages default to 60 seconds.
            seconds = 60
        }
        return .seconds(seconds)
    }

    /// Checks whether a monitor's config is unchanged from the active config.
    private func configUnchanged(provider providerName: String, monitor: Monitor) -> Bool {
        guard let activeConfig else { return false }
        guard let activeProvider = activeConfig.serviceProviders.first(where: { $0.name == providerName }) else {
            return false
        }
        guard let activeMonitor = activeProvider.monitors.first(where: { $0.name == monitor.name }) else {
            return false
        }
        return activeMonitor == monitor
    }
}
