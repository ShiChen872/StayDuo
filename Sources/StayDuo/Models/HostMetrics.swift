import Foundation

enum MemoryPressure: Equatable {
    case normal
    case warning
    case critical

    var title: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "警告"
        case .critical: return "紧急"
        }
    }

    /// Maps both `kVMPressure*` (0–3) and dispatch bit flags (1 / 2 / 4).
    static func from(sysctlLevel level: Int32) -> MemoryPressure {
        switch level {
        case 0, 1:
            return .normal
        case 2:
            return .warning
        default:
            return .critical
        }
    }

    /// Health-style remaining: higher is better, so menu-bar colors match QuotaDuo.
    var healthPercent: Double {
        switch self {
        case .normal: return 100
        case .warning: return 30
        case .critical: return 5
        }
    }
}

struct HostMetrics: Equatable {
    var cpuPercent: Double?
    var load1: Double?
    var memoryUsedPercent: Double
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var memoryPressure: MemoryPressure
    var diskRemainingPercent: Double
    var diskFreeBytes: UInt64
    var diskTotalBytes: UInt64
    var volumeName: String?

    var menuBarText: String {
        let cpu = cpuPercent.map { "C\(Int($0.rounded()))" } ?? "C--"
        let memory = "M\(Int(memoryUsedPercent.rounded()))"
        let disk = "D\(Int(diskRemainingPercent.rounded()))"
        return "\(cpu)·\(memory)·\(disk)"
    }

    /// CPU/memory: lower usage is healthier. Disk: remaining is already healthy.
    var cpuHealthPercent: Double {
        100 - (cpuPercent ?? 0)
    }

    var memoryHealthPercent: Double {
        min(100 - memoryUsedPercent, memoryPressure.healthPercent)
    }

    var diskHealthPercent: Double {
        diskRemainingPercent
    }

    var memorySubtitle: String {
        "\(Self.formatBytes(memoryUsedBytes)) / \(Self.formatBytes(memoryTotalBytes)) · \(memoryPressure.title)"
    }

    var diskSubtitle: String {
        let name = volumeName.map { "\($0) · " } ?? ""
        return "\(name)\(Self.formatBytes(diskFreeBytes)) / \(Self.formatBytes(diskTotalBytes))"
    }

    var loadSubtitle: String {
        guard let load1 else { return "—" }
        return String(format: "load %.2f", load1)
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 {
            return String(format: "%.0f GB", gb)
        }
        if gb >= 10 {
            return String(format: "%.0f GB", gb.rounded())
        }
        return String(format: "%.1f GB", gb)
    }
}
