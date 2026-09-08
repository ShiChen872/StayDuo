import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class StayStore {
    private enum Keys {
        static let enabled = "stayduo.enabled"
        static let mode = "stayduo.mode"
        static let duration = "stayduo.duration"
    }

    var isEnabled: Bool {
        didSet {
            if persistEnabledPreference {
                UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
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
            UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode)
            apply()
        }
    }

    var duration: StayDuration {
        didSet {
            UserDefaults.standard.set(duration.rawValue, forKey: Keys.duration)
            if isEnabled {
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

    private let keeper = AssertionKeeper()
    private var didStart = false
    private var persistEnabledPreference = true
    private var metricsTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
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
        apply()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        apply()
        if isEnabled {
            scheduleExpiry()
        }
        Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            ) {
                await MainActor.run {
                    self?.apply()
                }
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

    func apply() {
        do {
            try keeper.apply(mode: mode, enabled: isEnabled)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func remainingDescription(now: Date = .now) -> String {
        if let lastError {
            return lastError
        }
        guard isEnabled else { return "已暂停" }
        guard let expiresAt else { return "保持唤醒中" }
        let seconds = expiresAt.timeIntervalSince(now)
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
        clearExpiry()
        keeper.releaseAll()
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
        guard let interval = duration.timeInterval else {
            expiresAt = nil
            return
        }
        let fireDate = Date().addingTimeInterval(interval)
        expiresAt = fireDate
        expiryTask = Task { [weak self] in
            let remaining = fireDate.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handleExpiry()
            }
        }
    }

    private func clearExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
        expiresAt = nil
    }

    private func handleExpiry() {
        guard isEnabled, let expiresAt, Date() >= expiresAt else { return }
        persistEnabledPreference = false
        isEnabled = false
        persistEnabledPreference = true
    }
}
