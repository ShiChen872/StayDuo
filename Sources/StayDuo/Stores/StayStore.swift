import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class StayStore {
    private enum Keys {
        static let enabled = "stayduo.enabled"
        static let mode = "stayduo.mode"
    }

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            apply()
        }
    }

    var mode: StayMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode)
            apply()
        }
    }

    var lastError: String?
    var isAssertionHeld = false

    private let keeper = AssertionKeeper()
    private var didStart = false

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
        apply()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        apply()
        Task { [weak self] in
            for await _ in NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            ) {
                await MainActor.run {
                    self?.apply()
                }
            }
        }
    }

    func apply() {
        do {
            try keeper.apply(mode: mode, enabled: isEnabled)
            isAssertionHeld = isEnabled
            lastError = nil
        } catch {
            isAssertionHeld = false
            lastError = error.localizedDescription
        }
    }

    func release() {
        keeper.releaseAll()
        isAssertionHeld = false
    }
}
