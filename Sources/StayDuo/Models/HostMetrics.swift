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
    var battery: BatteryStatus?

    var diskUsedPercent: Double {
        max(0, min(100, 100 - diskRemainingPercent))
    }

    var menuBarText: String {
        let cpu = cpuPercent.map { "C\(Self.twoDigits($0))" } ?? "C--"
        let memory = "M\(Self.twoDigits(memoryUsedPercent))"
        let disk = "D\(Self.twoDigits(diskUsedPercent))"
        return "\(cpu)·\(memory)·\(disk)"
    }

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
        "剩余 \(Self.formatBytes(diskFreeBytes))"
    }

    var loadSubtitle: String {
        guard let load1 else { return "—" }
        return String(format: "load %.2f", load1)
    }

    func batteryAlert(isEnabled: Bool, mode: StayMode) -> BatteryAlert {
        guard isEnabled, let battery, battery.isOnBattery else { return .none }
        let criticalLimit: Double
        let warningLimit: Double
        switch mode {
        case .screenOn:
            criticalLimit = 20
            warningLimit = 40
        case .screenOffKeepNet:
            criticalLimit = 15
            warningLimit = 30
        }
        if battery.percent <= criticalLimit { return .critical }
        if battery.percent <= warningLimit { return .warning }
        return .none
    }

    static func twoDigits(_ value: Double) -> String {
        let n = max(0, Int(value.rounded()))
        if n >= 100 { return "\(n)" }
        return String(format: "%02d", n)
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
