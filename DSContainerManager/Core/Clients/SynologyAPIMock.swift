import Foundation
import Tagged

// MARK: - Mock API Client

extension SynologyAPIClient {
    static let mock = SynologyAPIClient(
        login: { _, _, _, _ in
            DemoMode.authSession
        },
        logout: { _, _ in },
        listContainers: { _, _ in DockerContainer.mockList },
        getContainerDetail: { _, _, name in ContainerDetail.mock(name: name) },
        performContainerAction: { _, _, _, _ in },
        getContainerLogs: { _, _, name, _, _ in ContainerLog.mockList(for: name) },
        getContainerResources: { _, _ in ContainerResources.mockList },
        listProjects: { _, _ in ComposeProject.mockList },
        getProjectDetail: { _, _, projectId in
            ComposeProject.mockList.first { $0.id.rawValue == projectId } ?? ComposeProject.mockList[0]
        },
        performProjectAction: { _, _, _, _ in },
        getSystemUtilization: { _, _ in SystemUtilization.mock },
        getStorageInfo: { _, _ in StorageInfo.mock },
    )
}

// MARK: - Mock Container Data

extension DockerContainer {
    static let mockList: [DockerContainer] = [
        DockerContainer(
            id: ContainerID(rawValue: "demo-plex"),
            name: "plex",
            image: "plexinc/pms-docker:latest",
            status: .running,
            state: "running",
            created: Date(timeIntervalSinceNow: -86400 * 74),
            ports: [
                PortMapping(privatePort: 32400, publicPort: 32400, type: "tcp"),
            ],
        ),
        DockerContainer(
            id: ContainerID(rawValue: "demo-home-assistant"),
            name: "home-assistant",
            image: "ghcr.io/home-assistant/home-assistant:stable",
            status: .running,
            state: "running",
            created: Date(timeIntervalSinceNow: -86400 * 118),
            ports: [
                PortMapping(privatePort: 8123, publicPort: 8123, type: "tcp"),
            ],
        ),
        DockerContainer(
            id: ContainerID(rawValue: "demo-immich"),
            name: "immich-server",
            image: "ghcr.io/immich-app/immich-server:release",
            status: .running,
            state: "running",
            created: Date(timeIntervalSinceNow: -86400 * 39),
            ports: [
                PortMapping(privatePort: 2283, publicPort: 2283, type: "tcp"),
            ],
        ),
        DockerContainer(
            id: ContainerID(rawValue: "demo-pihole"),
            name: "pihole",
            image: "pihole/pihole:latest",
            status: .stopped,
            state: "exited",
            created: Date(timeIntervalSinceNow: -86400 * 203),
            ports: [
                PortMapping(privatePort: 53, publicPort: 53, type: "tcp"),
                PortMapping(privatePort: 53, publicPort: 53, type: "udp"),
                PortMapping(privatePort: 80, publicPort: 8080, type: "tcp"),
            ],
        ),
    ]
}

// MARK: - Mock Container Detail

extension ContainerDetail {
    static func mock(name: String) -> ContainerDetail {
        switch name {
        case "home-assistant":
            return ContainerDetail(
                name: "home-assistant",
                image: "ghcr.io/home-assistant/home-assistant:stable",
                status: .running,
                created: Date(timeIntervalSinceNow: -86400 * 118),
                env: [
                    "TZ=Europe/Warsaw",
                    "PUID=1000",
                    "PGID=1000",
                ],
                cmd: ["/init"],
                volumes: [
                    VolumeMount(source: "/volume1/docker/home-assistant/config", destination: "/config"),
                    VolumeMount(source: "/etc/localtime", destination: "/etc/localtime", mode: "ro"),
                ],
                networks: ["host"],
                labels: composeLabels(project: "smart-home", service: "home-assistant"),
                hostConfig: HostConfig(
                    memoryLimit: 2_147_483_648,
                    cpuShares: 768,
                    restartPolicy: "unless-stopped",
                    networkMode: "host",
                ),
                ports: [
                    DockerContainer.PortMapping(privatePort: 8123, publicPort: 8123, type: "tcp"),
                ],
                restartPolicy: "unless-stopped",
            )

        case "immich-server":
            return ContainerDetail(
                name: "immich-server",
                image: "ghcr.io/immich-app/immich-server:release",
                status: .running,
                created: Date(timeIntervalSinceNow: -86400 * 39),
                env: [
                    "DB_HOSTNAME=immich-postgres",
                    "REDIS_HOSTNAME=immich-redis",
                    "UPLOAD_LOCATION=/usr/src/app/upload",
                    "TZ=Europe/Warsaw",
                ],
                cmd: ["start.sh"],
                volumes: [
                    VolumeMount(source: "/volume1/photos", destination: "/usr/src/app/upload"),
                    VolumeMount(source: "/volume1/docker/immich/model-cache", destination: "/cache"),
                ],
                networks: ["media"],
                labels: composeLabels(project: "photo-library", service: "immich-server"),
                hostConfig: HostConfig(
                    memoryLimit: 6_442_450_944,
                    cpuShares: 1536,
                    restartPolicy: "unless-stopped",
                    networkMode: "media",
                ),
                ports: [
                    DockerContainer.PortMapping(privatePort: 2283, publicPort: 2283, type: "tcp"),
                ],
                restartPolicy: "unless-stopped",
            )

        case "pihole":
            return ContainerDetail(
                name: "pihole",
                image: "pihole/pihole:latest",
                status: .stopped,
                created: Date(timeIntervalSinceNow: -86400 * 203),
                env: [
                    "TZ=Europe/Warsaw",
                    "WEBPASSWORD=********",
                    "DNSMASQ_LISTENING=all",
                ],
                cmd: ["/s6-init"],
                volumes: [
                    VolumeMount(source: "/volume1/docker/pihole/etc-pihole", destination: "/etc/pihole"),
                    VolumeMount(source: "/volume1/docker/pihole/dnsmasq.d", destination: "/etc/dnsmasq.d"),
                ],
                networks: ["bridge"],
                labels: composeLabels(project: "network-services", service: "pihole"),
                hostConfig: HostConfig(
                    memoryLimit: 536_870_912,
                    cpuShares: 512,
                    restartPolicy: "unless-stopped",
                    networkMode: "bridge",
                ),
                ports: [
                    DockerContainer.PortMapping(privatePort: 53, publicPort: 53, type: "tcp"),
                    DockerContainer.PortMapping(privatePort: 53, publicPort: 53, type: "udp"),
                    DockerContainer.PortMapping(privatePort: 80, publicPort: 8080, type: "tcp"),
                ],
                restartPolicy: "unless-stopped",
            )

        default:
            return ContainerDetail(
                name: "plex",
                image: "plexinc/pms-docker:latest",
                status: .running,
                created: Date(timeIntervalSinceNow: -86400 * 74),
                env: [
                    "PLEX_UID=1000",
                    "PLEX_GID=1000",
                    "TZ=Europe/Warsaw",
                    "ADVERTISE_IP=http://demo-nas.local:32400/",
                ],
                cmd: ["/init"],
                volumes: [
                    VolumeMount(source: "/volume1/docker/plex/config", destination: "/config"),
                    VolumeMount(source: "/volume1/media/movies", destination: "/movies", mode: "ro"),
                    VolumeMount(source: "/volume1/media/tv", destination: "/tv", mode: "ro"),
                ],
                networks: ["media"],
                labels: composeLabels(project: "media-server", service: "plex"),
                hostConfig: HostConfig(
                    memoryLimit: 4_294_967_296,
                    cpuShares: 1024,
                    restartPolicy: "unless-stopped",
                    networkMode: "media",
                ),
                ports: [
                    DockerContainer.PortMapping(privatePort: 32400, publicPort: 32400, type: "tcp"),
                ],
                restartPolicy: "unless-stopped",
            )
        }
    }

    private static func composeLabels(project: String, service: String) -> [String: String] {
        [
            "com.docker.compose.project": project,
            "com.docker.compose.service": service,
            "com.synology.demo": "true",
        ]
    }
}

// MARK: - Mock Container Logs

extension ContainerLog {
    static func mockList(for containerName: String = "plex") -> [ContainerLog] {
        let lines: [(LogStream, String)] = switch containerName {
        case "home-assistant":
            [
                (.stdout, "Home Assistant Core 2026.6.4 starting"),
                (.stdout, "Config directory: /config"),
                (.stdout, "Loaded 64 integrations"),
                (.stdout, "WebSocket API started on :8123"),
                (.stdout, "Automation initialized: evening lights"),
                (.stderr, "WARNING: Sensor kitchen_temperature unavailable"),
                (.stdout, "Recorder database cleanup completed"),
            ]
        case "immich-server":
            [
                (.stdout, "Immich API server listening on port 2283"),
                (.stdout, "Connected to PostgreSQL"),
                (.stdout, "Connected to Redis"),
                (.stdout, "Background worker: thumbnail generation started"),
                (.stdout, "Machine learning queue processed 128 assets"),
                (.stderr, "WARN: duplicate asset skipped: IMG_2042.HEIC"),
                (.stdout, "Library scan completed: 18,432 assets indexed"),
            ]
        case "pihole":
            [
                (.stdout, "Starting pihole-FTL"),
                (.stdout, "Imported gravity database"),
                (.stdout, "DNS service listening on 0.0.0.0:53"),
                (.stderr, "WARNING: container is currently stopped in demo state"),
                (.stdout, "Last query block rate: 27.4%"),
            ]
        default:
            [
                (.stdout, "Starting Plex Media Server"),
                (.stdout, "Loading configuration from /config/Library"),
                (.stdout, "Database migration complete"),
                (.stderr, "WARN: slow metadata refresh detected"),
                (.stdout, "Plex Media Server listening on port 32400"),
                (.stdout, "Library scan completed: Movies (1,247 items)"),
                (.stdout, "Stream started: demo-user - Direct Play"),
            ]
        }

        return lines.enumerated().map { index, entry in
            ContainerLog(
                id: UUID(),
                timestamp: Date(timeIntervalSinceNow: TimeInterval(-300 + index * 35)),
                stream: entry.0,
                text: entry.1,
                offset: index,
            )
        }
    }
}

// MARK: - Mock Container Resources

extension ContainerResources {
    static let mockList: [ContainerResources] = [
        ContainerResources(
            containerName: "plex",
            cpuPercent: 36.4,
            memoryUsage: 2_818_572_288,
            memoryLimit: 4_294_967_296,
            networkRx: 328_204_288,
            networkTx: 982_515_712,
            blockRead: 1_610_612_736,
            blockWrite: 352_321_536,
        ),
        ContainerResources(
            containerName: "home-assistant",
            cpuPercent: 9.7,
            memoryUsage: 621_805_568,
            memoryLimit: 2_147_483_648,
            networkRx: 42_467_328,
            networkTx: 18_874_368,
            blockRead: 228_589_568,
            blockWrite: 94_371_840,
        ),
        ContainerResources(
            containerName: "immich-server",
            cpuPercent: 58.9,
            memoryUsage: 4_429_185_024,
            memoryLimit: 6_442_450_944,
            networkRx: 702_545_920,
            networkTx: 418_381_824,
            blockRead: 2_251_799_552,
            blockWrite: 1_932_735_488,
        ),
        ContainerResources(
            containerName: "pihole",
            cpuPercent: 0,
            memoryUsage: 0,
            memoryLimit: 536_870_912,
            networkRx: 0,
            networkTx: 0,
            blockRead: 0,
            blockWrite: 0,
        ),
    ]
}

// MARK: - Mock Project Data

extension ComposeProject {
    static let mockList: [ComposeProject] = [
        ComposeProject(
            id: ProjectID(rawValue: "demo-media-server"),
            name: "media-server",
            status: .running,
            path: "/volume1/docker/media-server",
            sharePath: "docker/media-server",
            containerIds: ["demo-plex"],
            services: [
                ProjectService(id: "plex", displayName: "Plex", image: "plexinc/pms-docker:latest", status: .running),
            ],
            composeContent: """
            services:
              plex:
                image: plexinc/pms-docker:latest
                container_name: plex
                ports:
                  - "32400:32400"
                volumes:
                  - /volume1/docker/plex/config:/config
                  - /volume1/media/movies:/movies:ro
                  - /volume1/media/tv:/tv:ro
                restart: unless-stopped
            """,
            version: 1,
        ),
        ComposeProject(
            id: ProjectID(rawValue: "demo-smart-home"),
            name: "smart-home",
            status: .running,
            path: "/volume1/docker/smart-home",
            sharePath: "docker/smart-home",
            containerIds: ["demo-home-assistant"],
            services: [
                ProjectService(
                    id: "home-assistant",
                    displayName: "Home Assistant",
                    image: "ghcr.io/home-assistant/home-assistant:stable",
                    status: .running,
                ),
            ],
            composeContent: """
            services:
              home-assistant:
                image: ghcr.io/home-assistant/home-assistant:stable
                container_name: home-assistant
                network_mode: host
                volumes:
                  - /volume1/docker/home-assistant/config:/config
                restart: unless-stopped
            """,
            version: 1,
        ),
        ComposeProject(
            id: ProjectID(rawValue: "demo-photo-library"),
            name: "photo-library",
            status: .running,
            path: "/volume1/docker/photo-library",
            sharePath: "docker/photo-library",
            containerIds: ["demo-immich"],
            services: [
                ProjectService(
                    id: "immich-server",
                    displayName: "Immich",
                    image: "ghcr.io/immich-app/immich-server:release",
                    status: .running,
                ),
            ],
            composeContent: """
            services:
              immich-server:
                image: ghcr.io/immich-app/immich-server:release
                container_name: immich-server
                ports:
                  - "2283:2283"
                volumes:
                  - /volume1/photos:/usr/src/app/upload
                depends_on:
                  - immich-postgres
                  - immich-redis
                restart: unless-stopped
            """,
            version: 1,
        ),
        ComposeProject(
            id: ProjectID(rawValue: "demo-network-services"),
            name: "network-services",
            status: .stopped,
            path: "/volume1/docker/network-services",
            sharePath: "docker/network-services",
            containerIds: ["demo-pihole"],
            services: [
                ProjectService(id: "pihole", displayName: "Pi-hole", image: "pihole/pihole:latest", status: .stopped),
            ],
            composeContent: """
            services:
              pihole:
                image: pihole/pihole:latest
                container_name: pihole
                ports:
                  - "53:53/tcp"
                  - "53:53/udp"
                  - "8080:80/tcp"
                volumes:
                  - /volume1/docker/pihole/etc-pihole:/etc/pihole
                  - /volume1/docker/pihole/dnsmasq.d:/etc/dnsmasq.d
                restart: unless-stopped
            """,
            version: 1,
        ),
    ]
}

// MARK: - Mock System Utilization

extension SystemUtilization {
    static let mock = SystemUtilization(
        cpu: CPUInfo(
            userLoad: 29,
            systemLoad: 11,
            otherLoad: 4,
            oneMinLoad: 44,
            fiveMinLoad: 38,
            fifteenMinLoad: 31,
        ),
        memory: MemoryInfo(
            memorySize: 16_777_216,
            totalReal: 16_252_928,
            availReal: 5_526_016,
            totalSwap: 8_388_608,
            availSwap: 8_000_000,
            realUsage: 66,
            swapUsage: 5,
            cached: 4_194_304,
            buffer: 524_288,
        ),
        network: [
            NetworkInfo(device: "eth0", rx: 19_398_246, tx: 6_451_200),
            NetworkInfo(device: "total", rx: 19_398_246, tx: 6_451_200),
        ],
        disk: DiskOverview(
            disk: [
                DiskInfo(device: "sata1", displayName: "Drive 1", readByte: 3_145_728, writeByte: 1_572_864, utilization: 22),
                DiskInfo(device: "sata2", displayName: "Drive 2", readByte: 4_194_304, writeByte: 2_097_152, utilization: 24),
            ],
            total: DiskTotal(readByte: 7_340_032, writeByte: 3_670_016, utilization: 23),
        ),
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
                usedSize: 5_440_000_000_000,
                temperature: 37,
                driveType: "SHR",
            ),
            VolumeInfo(
                id: "volume_2",
                path: "/volume2",
                status: "normal",
                totalSize: 4_000_000_000_000,
                usedSize: 1_320_000_000_000,
                temperature: 35,
                driveType: "SSD Cache",
            ),
        ],
    )
}
