import Darwin
import Foundation
import IOKit.ps

struct HostSampler {
    private var previousCPU: CPUTicks?
    private var smoothedCPU: Double?
    private var lastDisk: DiskSample?
    private var sampleCount = 0
    private let cpuSmoothing = 0.35

    mutating func sample() -> HostMetrics {
        sampleCount += 1
        let cpu = sampleCPU()
        let memory = sampleMemory()
        if lastDisk == nil || sampleCount % 5 == 1 {
            lastDisk = sampleDisk()
        }
        let disk = lastDisk ?? .empty
        return HostMetrics(
            cpuPercent: cpu,
            load1: Self.loadAverage1(),
            memoryUsedPercent: memory.usedPercent,
            memoryUsedBytes: memory.usedBytes,
            memoryTotalBytes: memory.totalBytes,
            memoryPressure: memory.pressure,
            diskRemainingPercent: disk.remainingPercent,
            diskFreeBytes: disk.freeBytes,
            diskTotalBytes: disk.totalBytes,
            battery: Self.sampleBattery()
        )
    }
}

private struct CPUTicks {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    static func read() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    func usagePercent(since previous: CPUTicks) -> Double? {
        guard user >= previous.user,
              system >= previous.system,
              idle >= previous.idle,
              nice >= previous.nice
        else { return nil }

        let busy = (user - previous.user) + (system - previous.system) + (nice - previous.nice)
        let idleDelta = idle - previous.idle
        let total = busy + idleDelta
        guard total > 0 else { return nil }
        return min(100, max(0, Double(busy) / Double(total) * 100))
    }
}

private struct MemorySample {
    var usedPercent: Double
    var usedBytes: UInt64
    var totalBytes: UInt64
    var pressure: MemoryPressure
}

private struct DiskSample {
    var remainingPercent: Double
    var freeBytes: UInt64
    var totalBytes: UInt64

    static let empty = DiskSample(remainingPercent: 0, freeBytes: 0, totalBytes: 0)
}

private extension HostSampler {
    mutating func sampleCPU() -> Double? {
        guard let current = CPUTicks.read() else { return smoothedCPU }
        let raw = previousCPU.flatMap { current.usagePercent(since: $0) }
        previousCPU = current
        guard let raw else { return smoothedCPU }
        if let previous = smoothedCPU {
            smoothedCPU = cpuSmoothing * raw + (1 - cpuSmoothing) * previous
        } else {
            smoothedCPU = raw
        }
        return smoothedCPU
    }

    func sampleMemory() -> MemorySample {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        var used: UInt64 = 0
        if result == KERN_SUCCESS {
            let pageSize = Self.pageSize()
            let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
            used = pages * pageSize
        }
        if used > total, total > 0 {
            used = total
        }
        let percent = total == 0 ? 0 : min(100, Double(used) / Double(total) * 100)
        return MemorySample(
            usedPercent: percent,
            usedBytes: used,
            totalBytes: total,
            pressure: Self.memoryPressure()
        )
    }

    func sampleDisk() -> DiskSample {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              total > 0
        else { return .empty }

        let free: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            free = important
        } else {
            free = Int64(values.volumeAvailableCapacity ?? 0)
        }
        let freeClamped = max(0, min(Int64(total), free))
        let remaining = Double(freeClamped) / Double(total) * 100
        return DiskSample(
            remainingPercent: remaining,
            freeBytes: UInt64(freeClamped),
            totalBytes: UInt64(total)
        )
    }

    static func sampleBattery() -> BatteryStatus? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        let typeKey = kIOPSTypeKey as String
        let internalType = kIOPSInternalBatteryType as String
        let currentKey = kIOPSCurrentCapacityKey as String
        let maxKey = kIOPSMaxCapacityKey as String
        let chargingKey = kIOPSIsChargingKey as String
        let stateKey = kIOPSPowerSourceStateKey as String
        let batteryPower = kIOPSBatteryPowerValue as String
        let timeToEmptyKey = kIOPSTimeToEmptyKey as String

        for source in list {
            guard let raw = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  raw[typeKey] as? String == internalType
            else { continue }

            let current = (raw[currentKey] as? Int) ?? 0
            let maxCapacity = (raw[maxKey] as? Int) ?? 0
            let percent: Double
            if maxCapacity > 0 {
                percent = min(100, max(0, Double(current) / Double(maxCapacity) * 100))
            } else {
                percent = min(100, max(0, Double(current)))
            }
            let minutes = raw[timeToEmptyKey] as? Int
            return BatteryStatus(
                percent: percent,
                isCharging: raw[chargingKey] as? Bool ?? false,
                isOnBattery: (raw[stateKey] as? String) == batteryPower,
                minutesToEmpty: (minutes ?? 0) > 0 ? minutes : nil
            )
        }
        return nil
    }

    static func pageSize() -> UInt64 {
        var size: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &size)
        if result == KERN_SUCCESS, size > 0 {
            return UInt64(size)
        }
        return 16_384
    }

    static func memoryPressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard result == 0 else { return .normal }
        return MemoryPressure.from(sysctlLevel: level)
    }

    static func loadAverage1() -> Double? {
        var loads = [Double](repeating: 0, count: 3)
        let n = loads.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, 3)
        }
        guard n > 0 else { return nil }
        return loads[0]
    }
}
