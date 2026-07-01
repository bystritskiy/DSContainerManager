import Foundation

// MARK: - Container Resources (per-container resource usage)

struct ContainerResources: Equatable, Identifiable {
    nonisolated var id: String {
        containerName
    }

    let containerName: String
    let cpuPercent: Double
    let memoryUsage: Int64
    let memoryLimit: Int64
    let networkRx: Int64
    let networkTx: Int64
    let blockRead: Int64
    let blockWrite: Int64

    var memoryPercent: Double {
        guard memoryLimit > 0 else { return 0 }
        return Double(memoryUsage) / Double(memoryLimit) * 100
    }
}

// MARK: - Resource Snapshot (for time-series charts)

struct ResourceSnapshot: Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
    let networkRx: Int64
    let networkTx: Int64

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        cpuPercent: Double = 0,
        memoryPercent: Double = 0,
        networkRx: Int64 = 0,
        networkTx: Int64 = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.memoryPercent = memoryPercent
        self.networkRx = networkRx
        self.networkTx = networkTx
    }
}
