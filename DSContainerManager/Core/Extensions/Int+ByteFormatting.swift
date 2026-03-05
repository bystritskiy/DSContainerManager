import Foundation

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .binary)
    }

    var formattedBytesShort: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: self)
    }
}

extension Int {
    var formattedBytes: String {
        Int64(self).formattedBytes
    }

    /// Format as kilobytes (Synology reports memory in KB)
    var formattedKilobytes: String {
        Int64(self * 1024).formattedBytes
    }
}

extension Double {
    var formattedPercent: String {
        String(format: "%.1f%%", self)
    }

    var formattedPercentRounded: String {
        String(format: "%.0f%%", self)
    }
}
