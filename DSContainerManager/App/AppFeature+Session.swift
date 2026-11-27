import ComposableArchitecture
import Foundation

/// Connection lifecycle helpers for `AppFeature`: applying, restoring, renewing, and ending a session.
extension AppFeature {
    // MARK: - Helpers

    /// Signs in again with the stored password; the trusted-device token skips 2FA.
    func signInAgain(profile: ConnectionProfile, baseURL: URL) async -> AuthSession? {
        let password = (try? keychain.loadPassword(forConnection: profile.id)) ?? ""
        let deviceToken = try? keychain.loadDeviceToken(forConnection: profile.id)
        guard let session = try? await api.login(baseURL, profile.username, password, nil, deviceToken) else {
            return nil
        }
        try? keychain.saveSession(session, forConnection: profile.id)
        return session
    }

    /// Stops every poll and in-flight request, signs out of DSM, and returns to the connection list.
    func disconnect(state: inout State) -> Effect<Action> {
        let containerActionCancels = state.containerList.pendingActionIDs.map {
            Effect<Action>.cancel(id: ContainerListFeature.CancelID.action($0))
        }
        let projectActionCancels = state.projectList.pendingActionIDs.map {
            Effect<Action>.cancel(id: ProjectListFeature.CancelID.action($0))
        }
        var effects: [Effect<Action>] = Self.pollingAndLoadCancellations + [
            // Clear saved session from Keychain
            .run { _ in
                try? keychain.deleteSavedSession()
            },
            .run { _ in
                widgetData.clear()
            },
            // Reload quietly (no error reset), so "Last connected" is current and a sign-out message stays.
            .run { send in
                let result = await Result { try await connectionStore.fetchAll() }
                await send(.connectionList(.connectionsLoaded(result)))
            },
        ] + containerActionCancels + projectActionCancels

        // End the DSM session too, so it doesn't linger in DSM's connection list.
        if let baseURL = state.baseURL, let session = state.authSession, session != DemoMode.authSession {
            effects.append(.run { _ in
                try? await api.logout(baseURL, session)
            })
        }

        state.activeConnection = nil
        state.authSession = nil
        state.isRenewingSession = false
        state.lastSessionRenewal = nil
        state.dashboard = DashboardFeature.State()
        state.containerList = ContainerListFeature.State()
        state.projectList = ProjectListFeature.State()
        state.systemMonitor = SystemMonitorFeature.State()
        backgroundMonitor.cancelHealthCheck()
        return .merge(effects)
    }

    /// Every poll and load the features run; `disconnect` cancels them all.
    static var pollingAndLoadCancellations: [Effect<Action>] {
        [
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
        ]
    }

    /// Applies a connection + session to all child features and starts loading data
    func applyConnection(
        state: inout State,
        profile: ConnectionProfile,
        session: AuthSession,
    ) -> Effect<Action> {
        state.activeConnection = profile
        state.authSession = session
        state.showingConnectionSheet = false
        state.selectedTab = .dashboard
        if DemoMode.isEnabled, let screen = DemoMode.initialScreen {
            switch screen {
            case "containers", "container-info", "container-logs", "container-resources":
                state.selectedTab = .containers
            case "projects":
                state.selectedTab = .projects
            case "monitor":
                state.selectedTab = .monitor
            case "settings":
                state.selectedTab = .settings
            default:
                break
            }
        }

        let baseURL = profile.baseURL
        state.dashboard.nasName = profile.name
        state.dashboard.baseURL = baseURL
        state.dashboard.authSession = session
        state.containerList.baseURL = baseURL
        state.containerList.authSession = session
        state.projectList.baseURL = baseURL
        state.projectList.authSession = session
        state.systemMonitor.baseURL = baseURL
        state.systemMonitor.authSession = session

        var effects: [Effect<Action>] = [
            .send(.dashboard(.onAppear)),
            .send(.containerList(.onAppear)),
            .send(.projectList(.onAppear)),
        ]

        if session != DemoMode.authSession {
            // Background refresh keeps the widget current and drives container alerts when they're on.
            effects.append(.run { _ in
                backgroundMonitor.scheduleHealthCheck()
            })
        }

        return .merge(effects)
    }

    /// Opens the container a tapped notification was about, once it's in the loaded list.
    func presentPendingContainerIfNeeded(state: inout State) {
        guard state.isConnected,
              let name = state.pendingContainerName,
              let container = state.containerList.containers.first(where: { $0.name == name })
        else { return }
        state.pendingContainerName = nil
        state.selectedTab = .containers
        var detail = ContainerDetailFeature.State(container: container)
        detail.baseURL = state.containerList.baseURL
        detail.authSession = state.containerList.authSession
        state.containerList.detail = detail
    }

    /// In demo mode, auto-presents a container detail screen when `--demo-screen container-*` is passed,
    /// so screenshot automation can reach detail tabs without UI taps.
    func presentDemoContainerDetailIfNeeded(state: inout State) {
        guard DemoMode.isEnabled,
              let screen = DemoMode.initialScreen,
              screen.hasPrefix("container-"),
              state.containerList.detail == nil,
              let container = state.containerList.containers.first(where: { $0.name == "plex" })
              ?? state.containerList.containers.first
        else { return }

        var detail = ContainerDetailFeature.State(container: container)
        detail.baseURL = state.containerList.baseURL
        detail.authSession = state.containerList.authSession
        switch screen {
        case "container-logs":
            detail.selectedTab = .logs
        case "container-resources":
            detail.selectedTab = .resources
        default:
            detail.selectedTab = .info
        }
        state.containerList.detail = detail
    }

    /// Tries to restore a previously saved session from Keychain.
    /// Validates the session is still alive by making a lightweight API call.
    func restoreSavedSession() -> Effect<Action> {
        .run { send in
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

            await send(.sessionRestoreStarted(profile.id))

            // Validate session with a lightweight API call
            do {
                _ = try await api.getSystemUtilization(baseURL, saved.session)
                #if DEBUG
                    print("[AppFeature] Session is valid, restoring connection to \(profile.name)")
                #endif
                await send(.sessionRestored(profile, saved.session))
            } catch let error as SynologyAPIError where error.isSessionError {
                #if DEBUG
                    print("[AppFeature] Saved session expired, signing in again: \(error)")
                #endif
                // DSM dropped the session (timeout, reboot); sign in again with the stored credentials.
                guard let session = await signInAgain(profile: profile, baseURL: baseURL) else {
                    await send(.sessionValidationFailed)
                    return
                }
                await send(.sessionRestored(profile, session))
            } catch let error as SynologyAPIError where error.isNetworkError {
                #if DEBUG
                    print("[AppFeature] NAS unreachable while restoring session: \(error)")
                #endif
                await send(.sessionRestoreFailed(error.localizedDescription))
            } catch {
                #if DEBUG
                    print("[AppFeature] Saved session is invalid: \(error)")
                #endif
                await send(.sessionValidationFailed)
            }
        }
    }
}
