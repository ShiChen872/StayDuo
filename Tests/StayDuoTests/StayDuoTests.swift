import Foundation
import Testing
@testable import StayDuo

private final class MockAssertionKeeper: AssertionApplying {
    struct Call: Equatable {
        let mode: StayMode
        let enabled: Bool
    }

    private(set) var calls: [Call] = []
    private(set) var releaseCount = 0

    func apply(mode: StayMode, enabled: Bool) throws {
        calls.append(Call(mode: mode, enabled: enabled))
    }

    func releaseAll() {
        releaseCount += 1
    }
}

private func makeDefaults() -> UserDefaults {
    let suite = "StayDuoTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func makeHost(
    cpu: Double? = 12,
    memoryUsed: Double = 45,
    pressure: MemoryPressure = .normal,
    diskRemaining: Double = 70,
    battery: BatteryStatus? = nil
) -> HostMetrics {
    HostMetrics(
        cpuPercent: cpu,
        load1: 1.25,
        memoryUsedPercent: memoryUsed,
        memoryUsedBytes: 15_000_000_000,
        memoryTotalBytes: 32_000_000_000,
        memoryPressure: pressure,
        diskRemainingPercent: diskRemaining,
        diskFreeBytes: 350_000_000_000,
        diskTotalBytes: 500_000_000_000,
        battery: battery
    )
}

@Suite("HostMetrics & Models")
struct HostMetricsTests {
    @Test("Menu bar text zero-pads to two digits and handles missing CPU")
    func menuBarTextFormatting() {
        let host = makeHost(cpu: 4.2, memoryUsed: 57.4, diskRemaining: 76.2)
        #expect(host.menuBarText == "C04·M57·D24")

        let waitingCPU = makeHost(cpu: nil, memoryUsed: 100, diskRemaining: 0)
        #expect(waitingCPU.menuBarText == "C--·M100·D100")
    }

    @Test("MemoryPressure maps sysctl levels and health percents")
    func memoryPressureMapping() {
        #expect(MemoryPressure.from(sysctlLevel: 0) == .normal)
        #expect(MemoryPressure.from(sysctlLevel: 1) == .normal)
        #expect(MemoryPressure.from(sysctlLevel: 2) == .warning)
        #expect(MemoryPressure.from(sysctlLevel: 4) == .critical)
        #expect(MemoryPressure.normal.healthPercent == 100)
        #expect(MemoryPressure.warning.healthPercent == 30)
        #expect(MemoryPressure.critical.healthPercent == 5)
    }

    @Test("Battery alert thresholds vary by mode and power source")
    func batteryAlerts() {
        let onBattery35 = BatteryStatus(percent: 35, isCharging: false, isOnBattery: true, minutesToEmpty: 180)
        let onBattery18 = BatteryStatus(percent: 18, isCharging: false, isOnBattery: true, minutesToEmpty: 60)
        let onBattery12 = BatteryStatus(percent: 12, isCharging: false, isOnBattery: true, minutesToEmpty: 30)
        let onAC10 = BatteryStatus(percent: 10, isCharging: true, isOnBattery: false, minutesToEmpty: nil)

        #expect(makeHost(battery: onBattery35).batteryAlert(isEnabled: true, mode: .screenOn) == .warning)
        #expect(makeHost(battery: onBattery35).batteryAlert(isEnabled: true, mode: .screenOffKeepNet) == .none)
        #expect(makeHost(battery: onBattery18).batteryAlert(isEnabled: true, mode: .screenOn) == .critical)
        #expect(makeHost(battery: onBattery18).batteryAlert(isEnabled: true, mode: .screenOffKeepNet) == .warning)
        #expect(makeHost(battery: onBattery12).batteryAlert(isEnabled: true, mode: .screenOffKeepNet) == .critical)
        #expect(makeHost(battery: onBattery12).batteryAlert(isEnabled: false, mode: .screenOn) == .none)
        #expect(makeHost(battery: onAC10).batteryAlert(isEnabled: true, mode: .screenOn) == .none)
    }

    @Test("BatteryStatus formats line text across power states")
    func batteryLineText() {
        let charging = BatteryStatus(percent: 88, isCharging: true, isOnBattery: false, minutesToEmpty: nil)
        #expect(charging.lineText == "电池 88% · 充电中")

        let timed = BatteryStatus(percent: 92, isCharging: false, isOnBattery: true, minutesToEmpty: 125)
        #expect(timed.lineText == "电池 92% · 约 2 小时 5 分")

        let acPaused = BatteryStatus(percent: 80, isCharging: false, isOnBattery: false, minutesToEmpty: nil)
        #expect(acPaused.lineText == "电池 80% · 电源适配器")
    }
}

@Suite("StayStore")
@MainActor
struct StayStoreTests {
    @Test("Expiry pauses session without overwriting persisted enabled preference")
    func expiryPreservesEnabledPreference() {
        var current = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = makeDefaults()
        let keeper = MockAssertionKeeper()
        let store = StayStore(defaults: defaults, keeper: keeper, now: { current })

        // Explicitly persist enabled = true, then arm a 15-minute timer.
        store.isEnabled = false
        store.isEnabled = true
        store.selectDuration(.minutes15)
        #expect(store.isEnabled == true)
        #expect(store.expiresAt == current.addingTimeInterval(15 * 60))
        #expect(defaults.bool(forKey: StayStore.Keys.enabled) == true)

        current = current.addingTimeInterval(15 * 60 + 1)
        store.handleExpiry()

        #expect(store.isEnabled == false)
        #expect(store.expiresAt == nil)
        #expect(defaults.bool(forKey: StayStore.Keys.enabled) == true)
        #expect(keeper.calls.last == .init(mode: .screenOn, enabled: false))
    }

    @Test("Wake after expiry immediately pauses instead of re-applying assertion")
    func wakePastExpiryDoesNotReapply() {
        var current = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = makeDefaults()
        let keeper = MockAssertionKeeper()
        let store = StayStore(defaults: defaults, keeper: keeper, now: { current })

        store.selectDuration(.minutes15)
        let callsBeforeSleep = keeper.calls.count

        // Sleep longer than the 15-minute window
        current = current.addingTimeInterval(30 * 60)
        store.handleWake()

        #expect(store.isEnabled == false)
        #expect(store.expiresAt == nil)
        #expect(keeper.calls.count == callsBeforeSleep + 1)
        #expect(keeper.calls.last == .init(mode: .screenOn, enabled: false))
    }

    @Test("Wake before expiry preserves deadline and re-applies assertion")
    func wakeBeforeExpiryReapplies() {
        var current = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = makeDefaults()
        let keeper = MockAssertionKeeper()
        let store = StayStore(defaults: defaults, keeper: keeper, now: { current })

        store.selectDuration(.minutes30)
        let expectedDeadline = store.expiresAt
        let callsBeforeSleep = keeper.calls.count

        current = current.addingTimeInterval(5 * 60)
        store.handleWake()

        #expect(store.isEnabled == true)
        #expect(store.expiresAt == expectedDeadline)
        #expect(keeper.calls.count == callsBeforeSleep + 1)
        #expect(keeper.calls.last == .init(mode: .screenOn, enabled: true))
    }

    @Test("Selecting the same duration restarts timer and wakes paused store")
    func selectDurationRestartsAndWakes() {
        var current = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = makeDefaults()
        let keeper = MockAssertionKeeper()
        let store = StayStore(defaults: defaults, keeper: keeper, now: { current })

        store.selectDuration(.minutes15)
        let firstExpiry = store.expiresAt

        current = current.addingTimeInterval(120)
        store.selectDuration(.minutes15)
        #expect(store.expiresAt == firstExpiry?.addingTimeInterval(120))

        store.isEnabled = false
        store.selectMode(.screenOffKeepNet)
        #expect(store.isEnabled == true)
        #expect(store.mode == .screenOffKeepNet)
    }

    @Test("Remaining description formats states accurately")
    func remainingDescriptionFormatting() {
        let current = Date(timeIntervalSince1970: 1_700_000_000)
        let store = StayStore(defaults: makeDefaults(), keeper: MockAssertionKeeper(), now: { current })

        #expect(store.remainingDescription(now: current) == "保持唤醒中")

        store.selectDuration(.hours2)
        #expect(store.remainingDescription(now: current) == "还剩 2 小时")
        #expect(store.remainingDescription(now: current.addingTimeInterval(35 * 60)) == "还剩 1 小时 25 分")
        #expect(store.remainingDescription(now: current.addingTimeInterval(119 * 60 + 20)) == "还剩 1 分")

        store.isEnabled = false
        #expect(store.remainingDescription(now: current) == "已暂停")
    }
}
