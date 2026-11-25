import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var activeConnection: ConnectionProfile?
        var authSession: AuthSession?
        var connectionList = ConnectionFeature.State()
        var dashboard = DashboardFeature.State()
        var containerList = ContainerListFeature.State()
        var projectList = ProjectListFeature.State()
        var systemMonitor = SystemMonitorFeature.State()
        var showingConnectionSheet = false
        var hasAttemptedSessionRestore = false
        var isRenewingSession = false
        var lastSessionRenewal: Date?
        var containerAlertsEnabled = false
        var notificationsDenied = false
        /// A container to open once the list has loaded (from a tapped notification).
        var pendingContainerName: String?

        var isConnected: Bool {
            activeConnection != nil && authSession != nil
        }

        var baseURL: URL? {
            activeConnection?.baseURL
        }

        enum Tab: String, CaseIterable {
            case dashboard
            case containers
            case projects
            case monitor
            case settings

            var title: String {
                switch self {
                case .dashboard: "Dashboard"
                case .containers: "Containers"
                case .projects: "Projects"
                case .monitor: "Monitor"
                case .settings: "Settings"
                }
            }

            var systemImage: String {
                switch self {
                case .dashboard: "gauge.medium"
                case .containers: "shippingbox"
                case .projects: "folder"
                case .monitor: "chart.xyaxis.line"
                case .settings: "gear"
                }
            }
        }
    }

    enum Action {
        case onAppear
        case tabSelected(State.Tab)
        case connectionList(ConnectionFeature.Action)
        case dashboard(DashboardFeature.Action)
        case containerList(ContainerListFeature.Action)
        case projectList(ProjectListFeature.Action)
        case systemMonitor(SystemMonitorFeature.Action)
        case showConnectionSheet
        case hideConnectionSheet
        case disconnect
        case sessionRestoreStarted(UUID)
        case sessionRestored(ConnectionProfile, AuthSession)
        case sessionValidationFailed
        case sessionRestoreFailed(String)
        case sessionExpired
        case sessionRenewed(AuthSession)
        case sessionRenewalFailed
        case containerAlertsToggled(Bool)
        case containerAlertsAuthorization(Bool)
        case notificationOpened(containerName: String)
    }

    @Dependency(\.backgroundMonitor) var backgroundMonitor
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.synologyClient) var api
    @Dependency(\.connectionStore) var connectionStore
    @Dependency(\.widgetData) var widgetData
    @Dependency(\.date.now) var now

    nonisolated var body: some ReducerOf<Self> {
        Scope(state: \.connectionList, action: \.connectionList) {
            ConnectionFeature()
        }
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.containerList, action: \.containerList) {
            ContainerListFeature()
        }
        Scope(state: \.projectList, action: \.projectList) {
            ProjectListFeature()
        }
        Scope(state: \.systemMonitor, action: \.systemMonitor) {
            SystemMonitorFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasAttemptedSessionRestore else { return .none }
                state.hasAttemptedSessionRestore = true
                state.containerAlertsEnabled = backgroundMonitor.alertsEnabled()
                return .merge(
                    .send(.connectionList(.loadConnections)),
                    restoreSavedSession(),
                )

            case let .sessionRestoreStarted(connectionId):
                state.connectionList.loginInProgressId = connectionId
                return .none

            case let .sessionRestored(profile, session):
                state.connectionList.loginInProgressId = nil
                return applyConnection(state: &state, profile: profile, session: session)

            case .sessionValidationFailed:
                // Saved session was invalid/expired, clear it and show login
                state.connectionList.loginInProgressId = nil
                return .run { _ in
                    try? keychain.deleteSavedSession()
                }

            case let .sessionRestoreFailed(message):
                // The NAS is unreachable right now; keep the saved session for the next launch.
                state.connectionList.loginInProgressId = nil
                state.connectionList.error = message
                return .none

            case .sessionExpired:
                guard !state.isRenewingSession,
                      let profile = state.activeConnection,
                      let baseURL = profile.baseURL,
                      state.authSession != DemoMode.authSession
                else { return .none }
                // A fresh session rejected again right away won't be fixed by another sign-in; stop the loop.
                if let last = state.lastSessionRenewal, now.timeIntervalSince(last) < 60 {
                    return .send(.sessionRenewalFailed)
                }
                state.isRenewingSession = true
                return .run { send in
                    if let session = await signInAgain(profile: profile, baseURL: baseURL) {
                        await send(.sessionRenewed(session))
                    } else {
                        await send(.sessionRenewalFailed)
                    }
                }

            case let .sessionRenewed(session):
                state.isRenewingSession = false
                state.lastSessionRenewal = now
                guard state.isConnected else { return .none }
                state.authSession = session
                state.dashboard.authSession = session
                state.containerList.authSession = session
                state.containerList.detail?.authSession = session
                state.projectList.authSession = session
                state.projectList.detail?.authSession = session
                state.systemMonitor.authSession = session
                var effects: [Effect<Action>] = [
                    .send(.dashboard(.refresh)),
                    .send(.containerList(.refresh)),
                    .send(.projectList(.refresh)),
                    .send(.systemMonitor(.refresh)),
                ]
                if state.containerList.detail != nil {
                    effects.append(.send(.containerList(.detail(.presented(.refreshDetail)))))
                }
                if state.projectList.detail != nil {
                    effects.append(.send(.projectList(.detail(.presented(.refreshProject)))))
                }
                return .merge(effects)

            case .sessionRenewalFailed:
                state.isRenewingSession = false
                guard state.isConnected else { return .none }
                let effect = disconnect(state: &state)
                state.connectionList.error = "Your session has ended. Sign in again."
                return effect

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .containerAlertsToggled(isOn):
                state.containerAlertsEnabled = isOn
                state.notificationsDenied = false
                guard isOn else {
                    return .run { _ in
                        backgroundMonitor.setAlertsEnabled(false)
                    }
                }
                return .run { send in
                    await send(.containerAlertsAuthorization(backgroundMonitor.requestNotificationPermission()))
                }

            case let .containerAlertsAuthorization(granted):
                state.containerAlertsEnabled = granted
                state.notificationsDenied = !granted
                return .run { _ in
                    backgroundMonitor.setAlertsEnabled(granted)
                }

            case let .notificationOpened(containerName):
                state.pendingContainerName = containerName
                presentPendingContainerIfNeeded(state: &state)
                return .none

            case .dashboard(.delegate(.showAllContainers)):
                state.selectedTab = .containers
                state.containerList.statusFilter = nil
                state.containerList.searchText = ""
                state.containerList.detail = nil
                return .none

            case let .dashboard(.delegate(.showContainers(status))):
                state.selectedTab = .containers
                state.containerList.statusFilter = status
                state.containerList.searchText = ""
                state.containerList.detail = nil
                return .none

            case let .dashboard(.delegate(.showContainer(container))):
                state.selectedTab = .containers
                return .send(.containerList(.containerTapped(container)))

            case .showConnectionSheet:
                state.showingConnectionSheet = true
                return .none

            case .hideConnectionSheet:
                state.showingConnectionSheet = false
                return .none

            case .disconnect:
                return disconnect(state: &state)

            case let .connectionList(.delegate(.connectionEstablished(profile, session))):
                // Save session to Keychain for next launch
                let connectionId = profile.id
                let profile = profile.withLastConnected(now)
                return .merge(
                    applyConnection(state: &state, profile: profile, session: session),
                    .run { _ in
                        try? keychain.saveSession(session, forConnection: connectionId)
                        try? await connectionStore.save(profile)
                    },
                )

            case .connectionList:
                return .none

            case .dashboard(.dataLoaded(.success)):
                // Publish a snapshot for the home-screen widget; demo data must not replace real data.
                guard let profile = state.activeConnection, state.authSession != DemoMode.authSession else {
                    return .none
                }
                let snapshot = SharedContainerData(
                    nasName: profile.name,
                    containers: state.dashboard.containers,
                    cpuPercent: state.dashboard.cpuPercent,
                    memoryPercent: state.dashboard.memoryPercent,
                )
                return .run { _ in
                    widgetData.update(snapshot)
                }

            case let .dashboard(.dataLoaded(.failure(error))),
                 let .containerList(.containersLoaded(.failure(error))),
                 let .containerList(.actionResult(_, .failure(error))),
                 let .containerList(.detail(.presented(.detailLoaded(.failure(error))))),
                 let .containerList(.detail(.presented(.actionResult(.failure(error))))),
                 let .projectList(.projectsLoaded(.failure(error))),
                 let .projectList(.actionResult(_, .failure(error))),
                 let .projectList(.detail(.presented(.projectLoaded(.failure(error))))),
                 let .projectList(.detail(.presented(.actionResult(.failure(error))))),
                 let .systemMonitor(.utilizationLoaded(.failure(error))):
                guard (error as? SynologyAPIError)?.isSessionError == true else { return .none }
                return .send(.sessionExpired)

            case .dashboard:
                return .none

            case .containerList(.containersLoaded(.success)):
                presentDemoContainerDetailIfNeeded(state: &state)
                presentPendingContainerIfNeeded(state: &state)
                return .none

            case .containerList:
                return .none

            case .projectList:
                return .none

            case .systemMonitor:
                return .none
            }
        }
    }
}
