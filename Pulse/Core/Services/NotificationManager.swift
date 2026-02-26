import Foundation
import Observation
import UserNotifications
import os

/// Manages native macOS notifications for service status changes.
///
/// Stores user preferences (enabled state, which statuses trigger notifications)
/// in `UserDefaults` and posts `UNUserNotification`s when services transition
/// to a non-operational state.
@Observable
@MainActor
final class NotificationManager {

    // MARK: - UserDefaults keys

    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let notifiableStatuses = "notifiableStatuses"
    }

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "NotificationManager")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.center = UNUserNotificationCenter.current()

        defaults.register(defaults: [
            Key.notificationsEnabled: true,
            Key.notifiableStatuses: [MonitorStatus.degraded.rawValue, MonitorStatus.downtime.rawValue],
        ])

        _isEnabled = defaults.bool(forKey: Key.notificationsEnabled)

        let storedRawValues = defaults.stringArray(forKey: Key.notifiableStatuses) ?? []
        _notifiableStatuses = Set(storedRawValues.compactMap { MonitorStatus(rawValue: $0) })
    }

    // MARK: - Settings

    /// Whether notifications are enabled globally.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.notificationsEnabled) }
    }

    /// The set of statuses that should trigger a notification.
    var notifiableStatuses: Set<MonitorStatus> {
        didSet { defaults.set(notifiableStatuses.map(\.rawValue), forKey: Key.notifiableStatuses) }
    }

    /// All statuses the user can choose to be notified about.
    static let selectableStatuses: [MonitorStatus] = [.operational, .degraded, .downtime, .maintenance]

    // MARK: - Permission

    /// Requests notification authorization from the system.
    func requestPermission() {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                logger.info("Notification permission granted: \(granted)")
            } catch {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sending

    /// Posts a notification for a monitor that transitioned to a non-operational status.
    ///
    /// Call this only after verifying that:
    /// - Notifications are enabled
    /// - The new status is in `notifiableStatuses`
    /// - The provider is not silenced
    func sendStatusNotification(
        providerName: String,
        monitorDisplayName: String,
        status: MonitorStatus
    ) {
        let content = UNMutableNotificationContent()
        content.title = providerName
        content.body = "\(monitorDisplayName) is \(status.label.lowercased())"
        content.sound = .default

        let identifier = "\(providerName)-\(monitorDisplayName)-\(status.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        Task {
            do {
                try await center.add(request)
            } catch {
                logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}
