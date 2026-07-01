import Foundation

// MARK: - System Utilization

struct SystemUtilization: Codable, Equatable {
    let cpu: CPUInfo
    let memory: MemoryInfo
    let network: [NetworkInfo]
    let disk: DiskOverview?

    init(cpu: CPUInfo, memory: MemoryInfo, network: [NetworkInfo], disk: DiskOverview?) {
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.disk = disk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cpu = (try? container.decode(CPUInfo.self, forKey: .cpu))
            ?? CPUInfo(userLoad: 0, systemLoad: 0, otherLoad: 0, oneMinLoad: 0, fiveMinLoad: 0, fifteenMinLoad: 0)
        memory = (try? container.decode(MemoryInfo.self, forKey: .memory))
            ?? MemoryInfo(memorySize: 0, totalReal: 0, availReal: 0, totalSwap: 0, availSwap: 0, realUsage: 0, swapUsage: 0, cached: 0, buffer: 0)
        network = (try? container.decode([NetworkInfo].self, forKey: .network)) ?? []
        disk = try? container.decode(DiskOverview.self, forKey: .disk)
    }

    enum CodingKeys: String, CodingKey {
        case cpu, memory, network, disk
    }
}

// MARK: - CPU Info

struct CPUInfo: Codable, Equatable {
    let userLoad: Int
    let systemLoad: Int
    let otherLoad: Int
    let oneMinLoad: Int
    let fiveMinLoad: Int
    let fifteenMinLoad: Int

    var totalLoad: Int {
        userLoad + systemLoad + otherLoad
    }

    var totalPercent: Double {
        min(Double(totalLoad), 100.0)
    }

    init(userLoad: Int, systemLoad: Int, otherLoad: Int, oneMinLoad: Int, fiveMinLoad: Int, fifteenMinLoad: Int) {
        self.userLoad = userLoad
        self.systemLoad = systemLoad
        self.otherLoad = otherLoad
        self.oneMinLoad = oneMinLoad
        self.fiveMinLoad = fiveMinLoad
        self.fifteenMinLoad = fifteenMinLoad
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userLoad = (try? container.decode(Int.self, forKey: .userLoad)) ?? 0
        systemLoad = (try? container.decode(Int.self, forKey: .systemLoad)) ?? 0
        otherLoad = (try? container.decode(Int.self, forKey: .otherLoad)) ?? 0
        oneMinLoad = (try? container.decode(Int.self, forKey: .oneMinLoad)) ?? 0
        fiveMinLoad = (try? container.decode(Int.self, forKey: .fiveMinLoad)) ?? 0
        fifteenMinLoad = (try? container.decode(Int.self, forKey: .fifteenMinLoad)) ?? 0
    }

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

struct MemoryInfo: Codable, Equatable {
    let memorySize: Int
    let totalReal: Int
    let availReal: Int
    let totalSwap: Int
    let availSwap: Int
    let realUsage: Int
    let swapUsage: Int
    let cached: Int
    let buffer: Int

    var usedReal: Int {
        totalReal - availReal
    }

    var usagePercent: Double {
        Double(realUsage)
    }

    init(memorySize: Int, totalReal: Int, availReal: Int, totalSwap: Int, availSwap: Int, realUsage: Int, swapUsage: Int, cached: Int, buffer: Int) {
        self.memorySize = memorySize
        self.totalReal = totalReal
        self.availReal = availReal
        self.totalSwap = totalSwap
        self.availSwap = availSwap
        self.realUsage = realUsage
        self.swapUsage = swapUsage
        self.cached = cached
        self.buffer = buffer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memorySize = (try? container.decode(Int.self, forKey: .memorySize)) ?? 0
        totalReal = (try? container.decode(Int.self, forKey: .totalReal)) ?? 0
        availReal = (try? container.decode(Int.self, forKey: .availReal)) ?? 0
        totalSwap = (try? container.decode(Int.self, forKey: .totalSwap)) ?? 0
        availSwap = (try? container.decode(Int.self, forKey: .availSwap)) ?? 0
        realUsage = (try? container.decode(Int.self, forKey: .realUsage)) ?? 0
        swapUsage = (try? container.decode(Int.self, forKey: .swapUsage)) ?? 0
        cached = (try? container.decode(Int.self, forKey: .cached)) ?? 0
        buffer = (try? container.decode(Int.self, forKey: .buffer)) ?? 0
    }

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

struct NetworkInfo: Codable, Equatable, Identifiable {
    nonisolated var id: String {
        device
    }

    let device: String
    let rx: Int
    let tx: Int

    init(device: String, rx: Int, tx: Int) {
        self.device = device
        self.rx = rx
        self.tx = tx
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = (try? container.decode(String.self, forKey: .device)) ?? "unknown"
        rx = (try? container.decode(Int.self, forKey: .rx)) ?? 0
        tx = (try? container.decode(Int.self, forKey: .tx)) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case device, rx, tx
    }
}

// MARK: - Disk Overview

struct DiskOverview: Codable, Equatable {
    let disk: [DiskInfo]
    let total: DiskTotal?

    init(disk: [DiskInfo], total: DiskTotal?) {
        self.disk = disk
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        disk = (try? container.decode([DiskInfo].self, forKey: .disk)) ?? []
        total = try? container.decode(DiskTotal.self, forKey: .total)
    }

    enum CodingKeys: String, CodingKey {
        case disk, total
    }
}

struct DiskInfo: Codable, Equatable, Identifiable {
    nonisolated var id: String {
        device
    }

    let device: String
    let displayName: String
    let readByte: Int
    let writeByte: Int
    let utilization: Int

    init(device: String, displayName: String, readByte: Int, writeByte: Int, utilization: Int) {
        self.device = device
        self.displayName = displayName
        self.readByte = readByte
        self.writeByte = writeByte
        self.utilization = utilization
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = (try? container.decode(String.self, forKey: .device)) ?? "unknown"
        displayName = (try? container.decode(String.self, forKey: .displayName)) ?? ""
        readByte = (try? container.decode(Int.self, forKey: .readByte)) ?? 0
        writeByte = (try? container.decode(Int.self, forKey: .writeByte)) ?? 0
        utilization = (try? container.decode(Int.self, forKey: .utilization)) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case device
        case displayName = "display_name"
        case readByte = "read_byte"
        case writeByte = "write_byte"
        case utilization
    }
}

struct DiskTotal: Codable, Equatable {
    let readByte: Int
    let writeByte: Int
    let utilization: Int

    init(readByte: Int, writeByte: Int, utilization: Int) {
        self.readByte = readByte
        self.writeByte = writeByte
        self.utilization = utilization
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readByte = (try? container.decode(Int.self, forKey: .readByte)) ?? 0
        writeByte = (try? container.decode(Int.self, forKey: .writeByte)) ?? 0
        utilization = (try? container.decode(Int.self, forKey: .utilization)) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case readByte = "read_byte"
        case writeByte = "write_byte"
        case utilization
    }
}

// MARK: - Storage Info (SYNO.Storage.CGI.Storage)

struct StorageInfo: Codable, Equatable {
    let volumes: [VolumeInfo]

    init(volumes: [VolumeInfo]) {
        self.volumes = volumes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        volumes = (try? container.decode([VolumeInfo].self, forKey: .volumes)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case volumes
    }
}

struct VolumeInfo: Equatable, Identifiable, Codable {
    init(id: String, path: String, status: String, totalSize: Int64, usedSize: Int64, temperature: Int? = nil, driveType: String? = nil) {
        self.id = id
        self.path = path
        self.status = status
        self.totalSize = totalSize
        self.usedSize = usedSize
        self.temperature = temperature
        self.driveType = driveType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .volumePath)
        try container.encode(status, forKey: .status)
        try container.encode(totalSize, forKey: .totalSize)
        try container.encode(totalSize - usedSize, forKey: .freeSize)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(driveType, forKey: .driveType)
    }

    let id: String
    let path: String
    let status: String
    let totalSize: Int64
    let usedSize: Int64
    let temperature: Int?
    let driveType: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // id: try string "id", or volume_id as int, or fallback
        if let idStr = try? container.decode(String.self, forKey: .id) {
            id = idStr
        } else if let volumeId = try? container.decode(Int.self, forKey: .volumeId) {
            id = "volume_\(volumeId)"
        } else {
            id = UUID().uuidString
        }

        // path: try vol_path, volume_path, or path
        path = (try? container.decode(String.self, forKey: .volPath))
            ?? (try? container.decode(String.self, forKey: .volumePath))
            ?? (try? container.decode(String.self, forKey: .pathAlt))
            ?? ""

        status = (try? container.decode(String.self, forKey: .status)) ?? "unknown"

        // totalSize: Synology returns size as string (e.g. "7676309151744"), try String then Int64
        if let sizeStr = try? container.decode(String.self, forKey: .totalSize),
           let size = Int64(sizeStr)
        {
            totalSize = size
        } else {
            totalSize = (try? container.decode(Int64.self, forKey: .totalSize)) ?? 0
        }

        // usedSize: Synology provides size_free_byte (not size_used_byte), compute used = total - free
        if let freeStr = try? container.decode(String.self, forKey: .freeSize),
           let free = Int64(freeStr)
        {
            usedSize = totalSize - free
        } else if let free = try? container.decode(Int64.self, forKey: .freeSize) {
            usedSize = totalSize - free
        } else if let sizeStr = try? container.decode(String.self, forKey: .usedSize),
                  let size = Int64(sizeStr)
        {
            usedSize = size
        } else {
            usedSize = (try? container.decode(Int64.self, forKey: .usedSize)) ?? 0
        }

        temperature = try? container.decode(Int.self, forKey: .temperature)
        driveType = (try? container.decode(String.self, forKey: .driveType))
            ?? (try? container.decode(String.self, forKey: .raidType))
            ?? (try? container.decode(String.self, forKey: .fsType))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case volumeId = "volume_id"
        case volPath = "vol_path"
        case volumePath = "volume_path"
        case pathAlt = "path"
        case status
        case totalSize = "size_total_byte"
        case freeSize = "size_free_byte"
        case usedSize = "size_used_byte"
        case temperature = "temp"
        case driveType = "drive_type"
        case raidType = "raid_type"
        case fsType = "fs_type"
    }

    var freeSize: Int64 {
        totalSize - usedSize
    }

    var usagePercent: Double {
        guard totalSize > 0 else { return 0 }
        return Double(usedSize) / Double(totalSize) * 100
    }
}
