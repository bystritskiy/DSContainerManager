import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Synology API Client Interface

@DependencyClient
struct SynologyAPIClient {
    /// Auth
    var login: @Sendable (
        _ baseURL: URL,
        _ username: String,
        _ password: String,
        _ otpCode: String?
    ) async throws -> AuthSession

    var logout: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> Void

    /// Containers
    var listContainers: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> [DockerContainer]

    var getContainerDetail: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession,
        _ containerName: String
    ) async throws -> ContainerDetail

    var performContainerAction: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession,
        _ containerName: String,
        _ action: ContainerAction
    ) async throws -> Void

    var getContainerLogs: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession,
        _ containerName: String,
        _ offset: Int,
        _ limit: Int
    ) async throws -> [ContainerLog]

    var getContainerResources: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> [ContainerResources]

    /// Projects
    var listProjects: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> [ComposeProject]

    var getProjectDetail: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession,
        _ projectId: String
    ) async throws -> ComposeProject

    var performProjectAction: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession,
        _ projectId: String,
        _ action: ProjectAction
    ) async throws -> Void

    /// System
    var getSystemUtilization: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> SystemUtilization

    var getStorageInfo: @Sendable (
        _ baseURL: URL,
        _ session: AuthSession
    ) async throws -> StorageInfo
}

// MARK: - Dependency Registration

extension SynologyAPIClient: TestDependencyKey {
    static let testValue = SynologyAPIClient()
    static let previewValue = SynologyAPIClient.mock
}

extension DependencyValues {
    var synologyClient: SynologyAPIClient {
        get { self[SynologyAPIClient.self] }
        set { self[SynologyAPIClient.self] = newValue }
    }
}
