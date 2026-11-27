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
    /// Whether people asked to be told when a container stops (Settings › Notifications).
    var alertsEnabled: @Sendable () -> Bool
    var setAlertsEnabled: @Sendable (_ enabled: Bool) -> Void
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
                scheduleNextHealthCheck()
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
        alertsEnabled: {
            SharedStorage.sharedDefaults?.bool(forKey: AlertSettings.enabledKey) ?? false
        },
        setAlertsEnabled: { enabled in
            SharedStorage.sharedDefaults?.set(enabled, forKey: AlertSettings.enabledKey)
        },
    )

    static let testValue = BackgroundMonitorClient(
        registerTasks: {},
        scheduleHealthCheck: {},
        cancelHealthCheck: {},
        requestNotificationPermission: { true },
        alertsEnabled: { false },
        setAlertsEnabled: { _ in },
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
}

enum NotificationUserInfoKeys {
    static let containerName = "containerName"
    static let connectionId = "connectionId"
}

private enum AlertSettings {
    static let enabledKey = "containerAlertsEnabled"
}

// MARK: - Notification Setup

func setupNotificationCategories() {
    // Runs in the background: restarting doesn't need the app on screen.
    let restartAction = UNNotificationAction(
        identifier: NotificationActions.restart,
        title: "Restart",
        options: [],
    )

    let statusCategory = UNNotificationCategory(
        identifier: NotificationCategories.containerStatusChange,
        actions: [restartAction],
        intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "A container stopped",
        options: [],
    )

    UNUserNotificationCenter.current().setNotificationCategories([statusCategory])
}

// MARK: - Background Session

/// Signs in with what the app saved (session, password, trusted-device token) so background
/// work can reach the NAS while the app isn't running.
enum BackgroundSession {
    struct Context {
        let profile: ConnectionProfile
        let baseURL: URL
        var session: AuthSession
    }

    static func current() async -> Context? {
        @Dependency(\.keychainClient) var keychain
        @Dependency(\.connectionStore) var connectionStore

        guard let saved = try? keychain.loadSavedSession(),
              let profiles = try? await connectionStore.fetchAll(),
              let profile = profiles.first(where: { $0.id == saved.connectionId }),
              let baseURL = profile.baseURL
        else { return nil }
        return Context(profile: profile, baseURL: baseURL, session: saved.session)
    }

    /// Runs `body`, signing in again once if DSM has dropped the saved session.
    static func perform<T>(
        _ context: inout Context,
        _ body: (URL, AuthSession) async throws -> T,
    ) async throws -> T {
        @Dependency(\.keychainClient) var keychain
        @Dependency(\.synologyClient) var api

        do {
            return try await body(context.baseURL, context.session)
        } catch let error as SynologyAPIError where error.isSessionError {
            let password = (try? keychain.loadPassword(forConnection: context.profile.id)) ?? ""
            let deviceToken = try? keychain.loadDeviceToken(forConnection: context.profile.id)
            let session = try await api.login(context.baseURL, context.profile.username, password, nil, deviceToken)
            try? keychain.saveSession(session, forConnection: context.profile.id)
            context.session = session
            return try await body(context.baseURL, session)
        }
    }
}

// MARK: - Health Check

/// Background refresh: updates the widget snapshot and, when alerts are on, notifies about
/// containers that were running at the last check and aren't anymore.
enum ContainerHealthCheck {
    static func run() async -> Bool {
        @Dependency(\.synologyClient) var api
        @Dependency(\.widgetData) var widgetData
        @Dependency(\.backgroundMonitor) var backgroundMonitor

        guard var context = await BackgroundSession.current() else {
            // Signed out: nothing to watch.
            return true
        }

        let containers: [DockerContainer]
        do {
            containers = try await BackgroundSession.perform(&context) { baseURL, session in
                try await api.listContainers(baseURL, session)
            }
        } catch {
            return false
        }
        let previous = SharedStorage.loadContainerData()
        let utilization = try? await BackgroundSession.perform(&context) { baseURL, session in
            try await api.getSystemUtilization(baseURL, session)
        }

        widgetData.update(SharedContainerData(
            nasName: context.profile.name,
            containers: containers,
            cpuPercent: utilization?.cpu.totalPercent ?? previous?.cpuPercent ?? 0,
            memoryPercent: utilization?.memory.usagePercent ?? previous?.memoryPercent ?? 0,
        ))

        guard backgroundMonitor.alertsEnabled(), let previous, previous.nasName == context.profile.name else {
            return true
        }

        let wasRunning = Set(previous.containers.filter { $0.status == ContainerStatus.running.rawValue }.map(\.name))
        for container in containers where wasRunning.contains(container.name) {
            guard container.status != .running, container.status != .restarting else { continue }
            await notifyStopped(container, nasName: context.profile.name, connectionId: context.profile.id)
        }
        return true
    }

    private static func notifyStopped(_ container: DockerContainer, nasName: String, connectionId: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = container.name
        content.body = "\(container.status.displayName) on \(nasName)"
        content.sound = .default
        content.threadIdentifier = connectionId.uuidString
        content.categoryIdentifier = NotificationCategories.containerStatusChange
        content.userInfo = [
            NotificationUserInfoKeys.containerName: container.name,
            NotificationUserInfoKeys.connectionId: connectionId.uuidString,
        ]

        let request = UNNotificationRequest(
            identifier: "container-\(connectionId.uuidString)-\(container.name)",
            content: content,
            trigger: nil, // Deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Responses

/// Handles taps on container alerts: Restart works in the background, a plain tap opens the container.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationResponder()

    /// Set by the app to show a container once it's on screen.
    nonisolated(unsafe) var openContainer: (@MainActor (String) -> Void)?

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let name = userInfo[NotificationUserInfoKeys.containerName] as? String else { return }

        switch response.actionIdentifier {
        case NotificationActions.restart:
            await restart(containerNamed: name)
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                openContainer?(name)
            }
        default:
            break
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private nonisolated func restart(containerNamed name: String) async {
        @Dependency(\.synologyClient) var api
        guard var context = await BackgroundSession.current() else { return }
        _ = try? await BackgroundSession.perform(&context) { baseURL, session in
            try await api.performContainerAction(baseURL, session, name, .restart)
        }
    }
}

// MARK: - Background Task Handler

#if os(iOS)
    private func scheduleNextHealthCheck() {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskIdentifiers.containerHealthCheck,
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
                print("Failed to schedule background health check: \(error)")
            #endif
        }
    }

    private func handleHealthCheck(task: BGAppRefreshTask) {
        scheduleNextHealthCheck()

        // BGTask isn't Sendable, but completing it from the task that did the work is the documented pattern.
        nonisolated(unsafe) let task = task
        let work = Task {
            let success = await ContainerHealthCheck.run()
            task.setTaskCompleted(success: success && !Task.isCancelled)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
#endif
