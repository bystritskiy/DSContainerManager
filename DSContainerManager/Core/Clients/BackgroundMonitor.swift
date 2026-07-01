#if canImport(BackgroundTasks)
    import BackgroundTasks
#endif
import Dependencies
import Foundation
import UserNotifications

// MARK: - Background Monitor Client

struct BackgroundMonitorClient {
    var registerTasks: @Sendable () -> Void
    var scheduleHealthCheck: @Sendable () -> Void
    var cancelHealthCheck: @Sendable () -> Void
    var requestNotificationPermission: @Sendable () async -> Bool
    var sendContainerNotification: @Sendable (
        _ containerName: String,
        _ previousStatus: String,
        _ currentStatus: String,
    ) async -> Void
}

// MARK: - Dependency Registration

extension BackgroundMonitorClient: DependencyKey {
    static let liveValue = BackgroundMonitorClient(
        registerTasks: {
            #if os(iOS)
                BGTaskScheduler.shared.register(
                    forTaskWithIdentifier: BackgroundTaskIdentifiers.containerHealthCheck,
                    using: nil,
                ) { task in
                    guard let bgTask = task as? BGAppRefreshTask else { return }
                    handleHealthCheck(task: bgTask)
                }
            #endif
        },
        scheduleHealthCheck: {
            #if os(iOS)
                let request = BGAppRefreshTaskRequest(
                    identifier: BackgroundTaskIdentifiers.containerHealthCheck,
                )
                request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
                do {
                    try BGTaskScheduler.shared.submit(request)
                } catch {
                    print("Failed to schedule background health check: \(error)")
                }
            #endif
        },
        cancelHealthCheck: {
            #if os(iOS)
                BGTaskScheduler.shared.cancel(
                    taskRequestWithIdentifier: BackgroundTaskIdentifiers.containerHealthCheck,
                )
            #endif
        },
        requestNotificationPermission: {
            do {
                return try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        },
        sendContainerNotification: { containerName, previousStatus, currentStatus in
            let content = UNMutableNotificationContent()
            content.title = "Container Status Changed"
            content.body = "\(containerName) changed from \(previousStatus) to \(currentStatus)"
            content.sound = .default
            content.categoryIdentifier = NotificationCategories.containerStatusChange

            if currentStatus.lowercased() == "stopped" {
                content.body = "\(containerName) has stopped unexpectedly"
                content.interruptionLevel = .timeSensitive
            }

            let request = UNNotificationRequest(
                identifier: "container-\(containerName)-\(UUID().uuidString)",
                content: content,
                trigger: nil, // Deliver immediately
            )

            try? await UNUserNotificationCenter.current().add(request)
        },
    )

    static let testValue = BackgroundMonitorClient(
        registerTasks: {},
        scheduleHealthCheck: {},
        cancelHealthCheck: {},
        requestNotificationPermission: { true },
        sendContainerNotification: { _, _, _ in },
    )
}

extension DependencyValues {
    var backgroundMonitor: BackgroundMonitorClient {
        get { self[BackgroundMonitorClient.self] }
        set { self[BackgroundMonitorClient.self] = newValue }
    }
}

// MARK: - Constants

enum BackgroundTaskIdentifiers {
    static let containerHealthCheck = "com.dscontainermanager.container-health-check"
}

enum NotificationCategories {
    static let containerStatusChange = "CONTAINER_STATUS_CHANGE"
}

enum NotificationActions {
    static let restart = "RESTART_CONTAINER"
    static let openApp = "OPEN_APP"
}

// MARK: - Notification Setup

func setupNotificationCategories() {
    let restartAction = UNNotificationAction(
        identifier: NotificationActions.restart,
        title: "Restart",
        options: [.foreground],
    )

    let openAction = UNNotificationAction(
        identifier: NotificationActions.openApp,
        title: "Open App",
        options: [.foreground],
    )

    let statusCategory = UNNotificationCategory(
        identifier: NotificationCategories.containerStatusChange,
        actions: [restartAction, openAction],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "Container status changed",
        options: .customDismissAction,
    )

    UNUserNotificationCenter.current().setNotificationCategories([statusCategory])
}

// MARK: - Background Task Handler

#if os(iOS)
    private func handleHealthCheck(task: BGAppRefreshTask) {
        // Schedule the next check
        let nextRequest = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskIdentifiers.containerHealthCheck,
        )
        nextRequest.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(nextRequest)

        // Attempt to use stored session info for health check.
        // In a full implementation, this would load the saved connection + session
        // from Keychain/SwiftData and query the API. For MVP we mark it completed.
        task.setTaskCompleted(success: true)
    }
#endif
