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
        case sessionRestored(ConnectionProfile, AuthSession)
        case sessionValidationFailed
    }

    @Dependency(\.backgroundMonitor) var backgroundMonitor
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.synologyClient) var api
    @Dependency(\.connectionStore) var connectionStore

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
                return .merge(
                    .send(.connectionList(.loadConnections)),
                    restoreSavedSession(),
                )

            case let .sessionRestored(profile, session):
                return applyConnection(state: &state, profile: profile, session: session)

            case .sessionValidationFailed:
                // Saved session was invalid/expired, clear it and show login
                return .run { _ in
                    try? keychain.deleteSavedSession()
                }

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .showConnectionSheet:
                state.showingConnectionSheet = true
                return .none

            case .hideConnectionSheet:
                state.showingConnectionSheet = false
                return .none

            case .disconnect:
                let containerActionCancels = state.containerList.pendingActionIDs.map {
                    Effect<Action>.cancel(id: ContainerListFeature.CancelID.action($0))
                }
                let projectActionCancels = state.projectList.pendingActionIDs.map {
                    Effect<Action>.cancel(id: ProjectListFeature.CancelID.action($0))
                }
                let effects: [Effect<Action>] = [
                    .send(.dashboard(.stopPolling)),
                    .send(.containerList(.stopPolling)),
                    .send(.systemMonitor(.stopPolling)),
                    .cancel(id: DashboardFeature.CancelID.load),
                    .cancel(id: DashboardFeature.CancelID.polling),
                    .cancel(id: ContainerListFeature.CancelID.load),
                    .cancel(id: ContainerListFeature.CancelID.polling),
                    .cancel(id: ContainerDetailFeature.CancelID.detail),
                    .cancel(id: ContainerDetailFeature.CancelID.logs),
                    .cancel(id: ContainerDetailFeature.CancelID.resources),
                    .cancel(id: ContainerDetailFeature.CancelID.action),
                    .cancel(id: ContainerDetailFeature.CancelID.resourcePolling),
                    .cancel(id: ProjectListFeature.CancelID.load),
                    .cancel(id: ProjectDetailFeature.CancelID.load),
                    .cancel(id: ProjectDetailFeature.CancelID.action),
                    .cancel(id: SystemMonitorFeature.CancelID.utilizationLoad),
                    .cancel(id: SystemMonitorFeature.CancelID.storageLoad),
                    .cancel(id: SystemMonitorFeature.CancelID.polling),
                    .run { _ in
                        try? keychain.deleteSavedSession()
                    },
                ] + containerActionCancels + projectActionCancels
                state.activeConnection = nil
                state.authSession = nil
                state.dashboard = DashboardFeature.State()
                state.containerList = ContainerListFeature.State()
                state.projectList = ProjectListFeature.State()
                state.systemMonitor = SystemMonitorFeature.State()
                backgroundMonitor.cancelHealthCheck()
                // Clear saved session from Keychain
                return .merge(effects)

            case let .connectionList(.delegate(.connectionEstablished(profile, session))):
                // Save session to Keychain for next launch
                let connectionId = profile.id
                return .merge(
                    applyConnection(state: &state, profile: profile, session: session),
                    .run { _ in
                        try? keychain.saveSession(session, forConnection: connectionId)
                    },
                )

            case .connectionList:
                return .none

            case .dashboard:
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

    // MARK: - Helpers

    /// Applies a connection + session to all child features and starts loading data
    private func applyConnection(state: inout State, profile: ConnectionProfile, session: AuthSession) -> Effect<Action> {
        state.activeConnection = profile
        state.authSession = session
        state.showingConnectionSheet = false
        state.selectedTab = .dashboard

        let baseURL = profile.baseURL
        state.dashboard.baseURL = baseURL
        state.dashboard.authSession = session
        state.containerList.baseURL = baseURL
        state.containerList.authSession = session
        state.projectList.baseURL = baseURL
        state.projectList.authSession = session
        state.systemMonitor.baseURL = baseURL
        state.systemMonitor.authSession = session

        return .merge(
            .send(.dashboard(.onAppear)),
            .send(.containerList(.onAppear)),
            .send(.projectList(.onAppear)),
            .run { _ in
                _ = await backgroundMonitor.requestNotificationPermission()
                backgroundMonitor.scheduleHealthCheck()
            },
        )
    }

    /// Tries to restore a previously saved session from Keychain.
    /// Validates the session is still alive by making a lightweight API call.
    private func restoreSavedSession() -> Effect<Action> {
        .run { send in
            #if DEBUG
                print("[AppFeature] Attempting to restore saved session...")
            #endif

            guard let saved = try? keychain.loadSavedSession() else {
                #if DEBUG
                    print("[AppFeature] No saved session found in Keychain")
                #endif
                return
            }

            #if DEBUG
                print("[AppFeature] Found saved session for connection: \(saved.connectionId)")
            #endif

            // Find the matching connection profile
            let connections = try await connectionStore.fetchAll()
            guard let profile = connections.first(where: { $0.id == saved.connectionId }),
                  let baseURL = profile.baseURL
            else {
                #if DEBUG
                    print("[AppFeature] Connection profile not found for saved session")
                #endif
                await send(.sessionValidationFailed)
                return
            }

            // Validate session with a lightweight API call
            do {
                _ = try await api.getSystemUtilization(baseURL, saved.session)
                #if DEBUG
                    print("[AppFeature] Session is valid, restoring connection to \(profile.name)")
                #endif
                await send(.sessionRestored(profile, saved.session))
            } catch {
                #if DEBUG
                    print("[AppFeature] Saved session expired or invalid: \(error)")
                #endif
                await send(.sessionValidationFailed)
            }
        }
    }
}
