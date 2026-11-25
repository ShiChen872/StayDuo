import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class StayStore {
    enum Keys {
        static let enabled = "stayduo.enabled"
        static let mode = "stayduo.mode"
        static let duration = "stayduo.duration"
    }

    var isEnabled: Bool {
        didSet {
            if persistEnabledPreference {
                defaults.set(isEnabled, forKey: Keys.enabled)
            }
            if isEnabled {
                scheduleExpiry()
            } else {
                clearExpiry()
            }
            apply()
        }
    }

    var mode: StayMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Keys.mode)
            apply()
        }
    }

    var duration: StayDuration {
        didSet {
            defaults.set(duration.rawValue, forKey: Keys.duration)
            if isEnabled, duration != oldValue {
                scheduleExpiry()
            }
        }
    }

    var lastError: String?
    var host: HostMetrics?
    var expiresAt: Date?

    var batteryAlert: BatteryAlert {
        host?.batteryAlert(isEnabled: isEnabled, mode: mode) ?? .none
    }

    private let defaults: UserDefaults
    private let keeper: any AssertionApplying
    private let now: () -> Date
    private var didStart = false
    private var persistEnabledPreference = true
    private var metricsTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var terminateTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        keeper: any AssertionApplying = AssertionKeeper(),
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.keeper = keeper
        self.now = now

        if defaults.object(forKey: Keys.enabled) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: Keys.enabled)
        }
        if let raw = defaults.string(forKey: Keys.mode), let parsed = StayMode(rawValue: raw) {
            mode = parsed
        } else {
            mode = .screenOn
        }
        if let raw = defaults.string(forKey: Keys.duration), let parsed = StayDuration(rawValue: raw) {
            duration = parsed
        } else {
            duration = .indefinite
        }
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        apply()
        if isEnabled {
            scheduleExpiry()
        }
        wakeTask = Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            ) {
                self?.handleWake()
            }
        }
        terminateTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.willTerminateNotification
            ) {
                self?.release()
            }
        }
        metricsTask = Task.detached { [weak self] in
            var sampler = HostSampler()
            while !Task.isCancelled {
                let snapshot = sampler.sample()
                let interval: Double = snapshot.battery?.isOnBattery == true ? 5 : 2
                await MainActor.run {
                    self?.host = snapshot
                }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func selectMode(_ newMode: StayMode) {
        mode = newMode
        if !isEnabled {
            isEnabled = true
        }
    }

    func selectDuration(_ newDuration: StayDuration) {
        let unchanged = (duration == newDuration)
        duration = newDuration
        if !isEnabled {
            isEnabled = true
        } else if unchanged {
            scheduleExpiry()
        }
    }

    func apply() {
        do {
            try keeper.apply(mode: mode, enabled: isEnabled)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleWake() {
        guard isEnabled else { return }
        if let expiresAt {
            if now() >= expiresAt {
                handleExpiry()
                return
            }
            scheduleExpiryTask(until: expiresAt)
        }
        apply()
    }

    func handleExpiry() {
        guard isEnabled, let expiresAt, now() >= expiresAt else { return }
        persistEnabledPreference = false
        isEnabled = false
        persistEnabledPreference = true
    }

    func remainingDescription(now current: Date = .now) -> String {
        if let lastError {
            return lastError
        }
        guard isEnabled else { return "已暂停" }
        guard let expiresAt else { return "保持唤醒中" }
        let seconds = expiresAt.timeIntervalSince(current)
        if seconds <= 0 { return "已暂停" }
        let minutes = Int(ceil(seconds / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let rem = minutes % 60
            if rem == 0 {
                return "还剩 \(hours) 小时"
            }
            return "还剩 \(hours) 小时 \(rem) 分"
        }
        return "还剩 \(max(minutes, 1)) 分"
    }

    func release() {
        metricsTask?.cancel()
        metricsTask = nil
        wakeTask?.cancel()
        wakeTask = nil
        terminateTask?.cancel()
        terminateTask = nil
        clearExpiry()
        keeper.releaseAll()
    }

    private func scheduleExpiry() {
        guard let interval = duration.timeInterval else {
            clearExpiry()
            return
        }
        let fireDate = now().addingTimeInterval(interval)
        expiresAt = fireDate
        scheduleExpiryTask(until: fireDate)
    }

    private func scheduleExpiryTask(until fireDate: Date) {
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            let remaining = fireDate.timeIntervalSince(self?.now() ?? Date())
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            self?.handleExpiry()
        }
    }

    private func clearExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
        expiresAt = nil
    }
}
