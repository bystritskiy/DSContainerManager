import Foundation
import Tagged

// MARK: - Mock API Client

extension SynologyAPIClient {
    static let mock = SynologyAPIClient(
        login: { _, _, _, _ in
            AuthSession(
                sid: SessionID(rawValue: "mock_sid_abc123"),
                synotoken: "mock_synotoken",
                deviceId: nil
            )
        },
        logout: { _, _ in },
        listContainers: { _, _ in DockerContainer.mockList },
        getContainerDetail: { _, _, name in ContainerDetail.mock(name: name) },
        performContainerAction: { _, _, _, _ in },
        getContainerLogs: { _, _, _, _, _ in ContainerLog.mockList },
        getContainerResources: { _, _ in ContainerResources.mockList },
        listProjects: { _, _ in ComposeProject.mockList },
        getProjectDetail: { _, _, _ in ComposeProject.mockList[0] },
        performProjectAction: { _, _, _, _ in },
        getSystemUtilization: { _, _ in SystemUtilization.mock },
        getStorageInfo: { _, _ in StorageInfo.mock }
    )
}

// MARK: - Mock Container Data

extension DockerContainer {
    static let mockList: [DockerContainer] = [
        DockerContainer(
            id: ContainerID(rawValue: "abc123def456"),
            name: "plex",
            image: "plexinc/pms-docker:latest",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 30),
            ports: [
                PortMapping(privatePort: 32400, publicPort: 32400, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "def456ghi789"),
            name: "homeassistant",
            image: "homeassistant/home-assistant:2024.12",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 60),
            ports: [
                PortMapping(privatePort: 8123, publicPort: 8123, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "ghi789jkl012"),
            name: "pihole",
            image: "pihole/pihole:latest",
            status: .stopped,
            state: "exited",
            created: Date.now.addingTimeInterval(-86400 * 90),
            ports: [
                PortMapping(privatePort: 53, publicPort: 53, type: "tcp"),
                PortMapping(privatePort: 53, publicPort: 53, type: "udp"),
                PortMapping(privatePort: 80, publicPort: 8080, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "jkl012mno345"),
            name: "portainer",
            image: "portainer/portainer-ce:latest",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 120),
            ports: [
                PortMapping(privatePort: 9443, publicPort: 9443, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "mno345pqr678"),
            name: "nginx-proxy",
            image: "jwilder/nginx-proxy:latest",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 45),
            ports: [
                PortMapping(privatePort: 80, publicPort: 80, type: "tcp"),
                PortMapping(privatePort: 443, publicPort: 443, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "pqr678stu901"),
            name: "grafana",
            image: "grafana/grafana:latest",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 15),
            ports: [
                PortMapping(privatePort: 3000, publicPort: 3000, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "stu901vwx234"),
            name: "redis",
            image: "redis:7-alpine",
            status: .running,
            state: "running",
            created: Date.now.addingTimeInterval(-86400 * 200),
            ports: [
                PortMapping(privatePort: 6379, publicPort: nil, type: "tcp"),
            ],
            isPackage: false
        ),
        DockerContainer(
            id: ContainerID(rawValue: "vwx234yza567"),
            name: "mariadb",
            image: "mariadb:10.11",
            status: .stopped,
            state: "exited",
            created: Date.now.addingTimeInterval(-86400 * 180),
            ports: [
                PortMapping(privatePort: 3306, publicPort: 3306, type: "tcp"),
            ],
            isPackage: false
        ),
    ]
}

// MARK: - Mock Container Detail

extension ContainerDetail {
    static func mock(name: String) -> ContainerDetail {
        ContainerDetail(
            name: name,
            image: "plexinc/pms-docker:latest",
            status: .running,
            created: Date.now.addingTimeInterval(-86400 * 30),
            env: [
                "PLEX_UID=1000",
                "PLEX_GID=1000",
                "TZ=Europe/London",
                "ADVERTISE_IP=http://192.168.1.100:32400/",
            ],
            cmd: ["/init"],
            volumes: [
                VolumeMount(source: "/volume1/docker/plex/config", destination: "/config", mode: "rw"),
                VolumeMount(source: "/volume1/media/movies", destination: "/movies", mode: "ro"),
                VolumeMount(source: "/volume1/media/tv", destination: "/tv", mode: "ro"),
            ],
            networks: ["bridge"],
            labels: [
                "com.docker.compose.project": "media-stack",
                "com.docker.compose.service": "plex",
            ],
            hostConfig: HostConfig(
                memoryLimit: 4_294_967_296,
                cpuShares: 1024,
                restartPolicy: "unless-stopped",
                networkMode: "bridge"
            ),
            ports: [
                DockerContainer.PortMapping(privatePort: 32400, publicPort: 32400, type: "tcp"),
            ],
            restartPolicy: "unless-stopped"
        )
    }
}

// MARK: - Mock Container Logs

extension ContainerLog {
    static let mockList: [ContainerLog] = [
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-300), stream: .stdout,
                     text: "Starting Plex Media Server...", offset: 0),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-295), stream: .stdout,
                     text: "Loading configuration from /config/Library", offset: 1),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-290), stream: .stdout,
                     text: "Database migration complete", offset: 2),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-285), stream: .stderr,
                     text: "WARN: Slow database query detected (450ms)", offset: 3),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-280), stream: .stdout,
                     text: "Plex Media Server started, listening on port 32400", offset: 4),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-120), stream: .stdout,
                     text: "Library scan started: Movies", offset: 5),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-60), stream: .stdout,
                     text: "Library scan completed: Movies (1,247 items)", offset: 6),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-30), stream: .stdout,
                     text: "New media detected: /movies/NewRelease.mkv", offset: 7),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-10), stream: .stderr,
                     text: "WARN: Transcoder memory usage high (3.2GB)", offset: 8),
        ContainerLog(id: UUID(), timestamp: Date.now.addingTimeInterval(-5), stream: .stdout,
                     text: "Stream started: user@192.168.1.50 - Movie.mkv (Direct Play)", offset: 9),
    ]
}

// MARK: - Mock Container Resources

extension ContainerResources {
    static let mockList: [ContainerResources] = [
        ContainerResources(containerName: "plex", cpuPercent: 45.2,
                           memoryUsage: 3_221_225_472, memoryLimit: 4_294_967_296,
                           networkRx: 52_428_800, networkTx: 157_286_400,
                           blockRead: 1_073_741_824, blockWrite: 536_870_912),
        ContainerResources(containerName: "homeassistant", cpuPercent: 12.8,
                           memoryUsage: 536_870_912, memoryLimit: 2_147_483_648,
                           networkRx: 10_485_760, networkTx: 5_242_880,
                           blockRead: 209_715_200, blockWrite: 104_857_600),
        ContainerResources(containerName: "portainer", cpuPercent: 2.1,
                           memoryUsage: 134_217_728, memoryLimit: 1_073_741_824,
                           networkRx: 1_048_576, networkTx: 524_288,
                           blockRead: 52_428_800, blockWrite: 26_214_400),
        ContainerResources(containerName: "nginx-proxy", cpuPercent: 1.5,
                           memoryUsage: 67_108_864, memoryLimit: 536_870_912,
                           networkRx: 104_857_600, networkTx: 209_715_200,
                           blockRead: 10_485_760, blockWrite: 5_242_880),
        ContainerResources(containerName: "grafana", cpuPercent: 8.3,
                           memoryUsage: 268_435_456, memoryLimit: 1_073_741_824,
                           networkRx: 5_242_880, networkTx: 10_485_760,
                           blockRead: 104_857_600, blockWrite: 52_428_800),
        ContainerResources(containerName: "redis", cpuPercent: 0.8,
                           memoryUsage: 33_554_432, memoryLimit: 268_435_456,
                           networkRx: 2_097_152, networkTx: 1_048_576,
                           blockRead: 5_242_880, blockWrite: 10_485_760),
    ]
}

// MARK: - Mock Project Data

extension ComposeProject {
    static let mockList: [ComposeProject] = [
        ComposeProject(
            id: ProjectID(rawValue: "proj-001-media"),
            name: "media-stack",
            status: .running,
            path: "/volume1/docker/media-stack",
            sharePath: "docker/media-stack",
            containerIds: ["plex", "jellyfin"],
            services: [
                ProjectService(id: "plex", displayName: "Plex", image: "plexinc/pms-docker:latest", status: .running),
            ],
            composeContent: """
            version: '3.8'
            services:
              plex:
                image: plexinc/pms-docker:latest
                container_name: plex
                ports:
                  - "32400:32400"
                volumes:
                  - /volume1/docker/plex/config:/config
                  - /volume1/media/movies:/movies
                  - /volume1/media/tv:/tv
                environment:
                  - PLEX_UID=1000
                  - PLEX_GID=1000
                  - TZ=Europe/London
                restart: unless-stopped
            """,
            version: 1
        ),
        ComposeProject(
            id: ProjectID(rawValue: "proj-002-network"),
            name: "network-stack",
            status: .partiallyRunning,
            path: "/volume1/docker/network-stack",
            sharePath: "docker/network-stack",
            containerIds: ["pihole", "nginx-proxy"],
            services: [
                ProjectService(id: "pihole", displayName: "Pi-hole", image: "pihole/pihole:latest", status: .stopped),
                ProjectService(id: "nginx-proxy", displayName: "Nginx Proxy", image: "jwilder/nginx-proxy:latest", status: .running),
            ],
            composeContent: """
            version: '3.8'
            services:
              pihole:
                image: pihole/pihole:latest
                container_name: pihole
                ports:
                  - "53:53/tcp"
                  - "53:53/udp"
                  - "8080:80/tcp"
                restart: unless-stopped
              nginx-proxy:
                image: jwilder/nginx-proxy:latest
                container_name: nginx-proxy
                ports:
                  - "80:80"
                  - "443:443"
                restart: always
            """,
            version: 1
        ),
        ComposeProject(
            id: ProjectID(rawValue: "proj-003-monitoring"),
            name: "monitoring",
            status: .running,
            path: "/volume1/docker/monitoring",
            sharePath: "docker/monitoring",
            containerIds: ["grafana", "prometheus"],
            services: [
                ProjectService(id: "grafana", displayName: "Grafana", image: "grafana/grafana:latest", status: .running),
            ],
            composeContent: nil,
            version: 1
        ),
        ComposeProject(
            id: ProjectID(rawValue: "proj-004-database"),
            name: "database",
            status: .stopped,
            path: "/volume1/docker/database",
            sharePath: "docker/database",
            containerIds: ["mariadb", "redis"],
            services: [
                ProjectService(id: "mariadb", displayName: "MariaDB", image: "mariadb:10.11", status: .stopped),
                ProjectService(id: "redis", displayName: "Redis", image: "redis:7-alpine", status: .stopped),
            ],
            composeContent: nil,
            version: 1
        ),
    ]
}

// MARK: - Mock System Utilization

extension SystemUtilization {
    static let mock = SystemUtilization(
        cpu: CPUInfo(
            userLoad: 25, systemLoad: 10, otherLoad: 3,
            oneMinLoad: 38, fiveMinLoad: 32, fifteenMinLoad: 28
        ),
        memory: MemoryInfo(
            memorySize: 16_777_216,
            totalReal: 16_252_928,
            availReal: 6_501_171,
            totalSwap: 8_388_608,
            availSwap: 8_000_000,
            realUsage: 60,
            swapUsage: 5,
            cached: 4_194_304,
            buffer: 524_288
        ),
        network: [
            NetworkInfo(device: "eth0", rx: 5_242_880, tx: 1_048_576),
            NetworkInfo(device: "total", rx: 5_242_880, tx: 1_048_576),
        ],
        disk: DiskOverview(
            disk: [
                DiskInfo(device: "sda", displayName: "Drive 1", readByte: 1_048_576, writeByte: 524_288, utilization: 15),
                DiskInfo(device: "sdb", displayName: "Drive 2", readByte: 2_097_152, writeByte: 1_048_576, utilization: 22),
            ],
            total: DiskTotal(readByte: 3_145_728, writeByte: 1_572_864, utilization: 18)
        )
    )
}

// MARK: - Mock Storage Info

extension StorageInfo {
    static let mock = StorageInfo(
        volumes: [
            VolumeInfo(
                id: "volume_1",
                path: "/volume1",
                status: "normal",
                totalSize: 8_000_000_000_000,
                usedSize: 5_600_000_000_000,
                temperature: 38,
                driveType: "RAID5"
            ),
            VolumeInfo(
                id: "volume_2",
                path: "/volume2",
                status: "normal",
                totalSize: 4_000_000_000_000,
                usedSize: 1_200_000_000_000,
                temperature: 36,
                driveType: "SHR"
            ),
        ]
    )
}
