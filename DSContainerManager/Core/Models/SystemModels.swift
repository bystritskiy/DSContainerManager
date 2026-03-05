import Foundation

// MARK: - System Utilization

struct SystemUtilization: Codable, Sendable, Equatable {
    let cpu: CPUInfo
    let memory: MemoryInfo
    let network: [NetworkInfo]
    let disk: DiskOverview?
}

// MARK: - CPU Info

struct CPUInfo: Codable, Sendable, Equatable {
    let userLoad: Int
    let systemLoad: Int
    let otherLoad: Int
    let oneMinLoad: Int
    let fiveMinLoad: Int
    let fifteenMinLoad: Int

    var totalLoad: Int { userLoad + systemLoad + otherLoad }
    var totalPercent: Double { min(Double(totalLoad), 100.0) }

    enum CodingKeys: String, CodingKey {
        case userLoad = "user_load"
        case systemLoad = "system_load"
        case otherLoad = "other_load"
        case oneMinLoad = "1min_load"
        case fiveMinLoad = "5min_load"
        case fifteenMinLoad = "15min_load"
    }
}

// MARK: - Memory Info

struct MemoryInfo: Codable, Sendable, Equatable {
    let memorySize: Int
    let totalReal: Int
    let availReal: Int
    let totalSwap: Int
    let availSwap: Int
    let realUsage: Int
    let swapUsage: Int
    let cached: Int
    let buffer: Int

    var usedReal: Int { totalReal - availReal }
    var usagePercent: Double { Double(realUsage) }

    enum CodingKeys: String, CodingKey {
        case memorySize = "memory_size"
        case totalReal = "total_real"
        case availReal = "avail_real"
        case totalSwap = "total_swap"
        case availSwap = "avail_swap"
        case realUsage = "real_usage"
        case swapUsage = "swap_usage"
        case cached
        case buffer
    }
}

// MARK: - Network Info

struct NetworkInfo: Codable, Sendable, Equatable, Identifiable {
    nonisolated var id: String { device }
    let device: String
    let rx: Int
    let tx: Int
}

// MARK: - Disk Overview

struct DiskOverview: Codable, Sendable, Equatable {
    let disk: [DiskInfo]
    let total: DiskTotal?
}

struct DiskInfo: Codable, Sendable, Equatable, Identifiable {
    nonisolated var id: String { device }
    let device: String
    let displayName: String
    let readByte: Int
    let writeByte: Int
    let utilization: Int

    enum CodingKeys: String, CodingKey {
        case device
        case displayName = "display_name"
        case readByte = "read_byte"
        case writeByte = "write_byte"
        case utilization
    }
}

struct DiskTotal: Codable, Sendable, Equatable {
    let readByte: Int
    let writeByte: Int
    let utilization: Int

    enum CodingKeys: String, CodingKey {
        case readByte = "read_byte"
        case writeByte = "write_byte"
        case utilization
    }
}

// MARK: - Storage Info (SYNO.Storage.CGI.Storage)

struct StorageInfo: Codable, Sendable, Equatable {
    let volumes: [VolumeInfo]
}

struct VolumeInfo: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let path: String
    let status: String
    let totalSize: Int64
    let usedSize: Int64
    let temperature: Int?
    let driveType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case path = "vol_path"
        case status
        case totalSize = "size_total_byte"
        case usedSize = "size_used_byte"
        case temperature = "temp"
        case driveType = "drive_type"
    }

    var freeSize: Int64 { totalSize - usedSize }
    var usagePercent: Double {
        guard totalSize > 0 else { return 0 }
        return Double(usedSize) / Double(totalSize) * 100
    }
}
