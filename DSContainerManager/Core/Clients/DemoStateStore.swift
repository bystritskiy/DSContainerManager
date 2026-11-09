import Foundation
import Tagged

/// Mutable in-memory state backing demo mode so container and project actions
/// produce visible changes instead of being no-ops.
actor DemoStateStore {
    static let shared = DemoStateStore()

    private var containers: [DockerContainer]
    private var details: [String: ContainerDetail]
    private var projects: [ComposeProject]
    private let baselineResources: [String: ContainerResources]

    init() {
        containers = DockerContainer.mockList
        details = Dictionary(
            uniqueKeysWithValues: DockerContainer.mockList.map { ($0.name, ContainerDetail.mock(name: $0.name)) },
        )
        projects = ComposeProject.mockList
        baselineResources = Dictionary(
            uniqueKeysWithValues: ContainerResources.mockList.map { ($0.containerName, $0) },
        )
    }

    // MARK: - Reads

    func allContainers() -> [DockerContainer] {
        containers
    }

    func containerDetail(name: String) -> ContainerDetail {
        details[name] ?? ContainerDetail.mock(name: name)
    }

    func allProjects() -> [ComposeProject] {
        projects
    }

    func project(id: String) -> ComposeProject? {
        projects.first { $0.id.rawValue == id }
    }

    func allResources() -> [ContainerResources] {
        containers.map { container in
            let baseline = baselineResources[container.name]
            guard container.status == .running, let baseline else {
                return ContainerResources(
                    containerName: container.name,
                    cpuPercent: 0,
                    memoryUsage: 0,
                    memoryLimit: baseline?.memoryLimit ?? 0,
                    networkRx: 0,
                    networkTx: 0,
                    blockRead: 0,
                    blockWrite: 0,
                )
            }
            return baseline
        }
    }

    // MARK: - Writes

    func perform(_ action: ContainerAction, containerName: String) {
        apply(status: Self.status(for: action), toContainerNamed: containerName)
        refreshProjectStatuses()
    }

    func perform(_ action: ProjectAction, projectId: String) {
        guard let project = projects.first(where: { $0.id.rawValue == projectId }) else { return }
        let status = Self.status(for: action)
        for containerId in project.containerIds {
            guard let name = containers.first(where: { $0.id.rawValue == containerId })?.name else { continue }
            apply(status: status, toContainerNamed: name)
        }
        refreshProjectStatuses()
    }

    // MARK: - Helpers

    private func apply(status: ContainerStatus, toContainerNamed name: String) {
        guard let index = containers.firstIndex(where: { $0.name == name }) else { return }
        let container = containers[index]
        containers[index] = DockerContainer(
            id: container.id,
            name: container.name,
            image: container.image,
            status: status,
            state: Self.state(for: status),
            created: container.created,
            ports: container.ports,
            isPackage: container.isPackage,
        )

        let detail = details[name] ?? ContainerDetail.mock(name: name)
        details[name] = ContainerDetail(
            name: detail.name,
            image: detail.image,
            status: status,
            created: detail.created,
            env: detail.env,
            cmd: detail.cmd,
            volumes: detail.volumes,
            networks: detail.networks,
            labels: detail.labels,
            hostConfig: detail.hostConfig,
            ports: detail.ports,
            restartPolicy: detail.restartPolicy,
        )
    }

    private func refreshProjectStatuses() {
        projects = projects.map { project in
            let projectContainers = project.containerIds.compactMap { containerId in
                containers.first { $0.id.rawValue == containerId }
            }
            let services = project.services.map { service in
                ProjectService(
                    id: service.id,
                    displayName: service.displayName,
                    image: service.image,
                    status: containers.first { $0.name == service.id }?.status ?? service.status,
                )
            }
            return ComposeProject(
                id: project.id,
                name: project.name,
                status: Self.projectStatus(for: projectContainers.map(\.status)),
                path: project.path,
                sharePath: project.sharePath,
                containerIds: project.containerIds,
                services: services,
                composeContent: project.composeContent,
                version: project.version,
            )
        }
    }

    private static func status(for action: ContainerAction) -> ContainerStatus {
        switch action {
        case .start, .restart, .unpause: .running
        case .stop, .kill: .stopped
        case .pause: .paused
        }
    }

    private static func status(for action: ProjectAction) -> ContainerStatus {
        switch action {
        case .start, .restart: .running
        case .stop: .stopped
        }
    }

    private static func state(for status: ContainerStatus) -> String {
        switch status {
        case .running: "running"
        case .stopped: "exited"
        case .paused: "paused"
        case .restarting: "restarting"
        case .created: "created"
        case .dead: "dead"
        case .unknown: "unknown"
        }
    }

    private static func projectStatus(for statuses: [ContainerStatus]) -> ProjectStatus {
        guard !statuses.isEmpty else { return .unknown }
        if statuses.allSatisfy({ $0 == .running }) {
            return .running
        }
        if statuses.contains(.running) {
            return .partiallyRunning
        }
        return .stopped
    }
}
