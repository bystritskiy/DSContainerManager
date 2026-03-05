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

        var isConnected: Bool { activeConnection != nil && authSession != nil }

        var baseURL: URL? { activeConnection?.baseURL }

        enum Tab: String, CaseIterable, Sendable {
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
    }

    @Dependency(\.backgroundMonitor) var backgroundMonitor

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
                return .send(.connectionList(.loadConnections))

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .showConnectionSheet:
                state.showingConnectionSheet = true
                return .none

            case .hideConnectionSheet:
                state.showingConnectionSheet = false
                return .none

            case .disconnect:
                state.activeConnection = nil
                state.authSession = nil
                state.dashboard = DashboardFeature.State()
                state.containerList = ContainerListFeature.State()
                state.projectList = ProjectListFeature.State()
                state.systemMonitor = SystemMonitorFeature.State()
                backgroundMonitor.cancelHealthCheck()
                return .none

            case .connectionList(.delegate(.connectionEstablished(let profile, let session))):
                state.activeConnection = profile
                state.authSession = session
                state.showingConnectionSheet = false
                state.selectedTab = .dashboard

                // Pass connection credentials to all child features
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
                    }
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
}
