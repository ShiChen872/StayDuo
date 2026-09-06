import Foundation
import IOKit.pwr_mgt

/// Holds IOKit power assertions while StayDuo is enabled.
///
/// - `PreventUserIdleDisplaySleep`: screen stays on (implies the Mac will not idle-sleep).
/// - `PreventUserIdleSystemSleep`: Mac stays awake so networking remains up; display may still sleep.
///
/// Closing the lid on Apple Silicon still sleeps unless you are in clamshell
/// (external display + power adapter). That is OS policy, not something a
/// menu-bar app can override on battery.
final class AssertionKeeper {
    private var assertionIDs: [IOPMAssertionID] = []

    func apply(mode: StayMode, enabled: Bool) throws {
        releaseAll()
        guard enabled else { return }

        switch mode {
        case .screenOn:
            try create(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                reason: "StayDuo: keep display awake"
            )
            try create(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                reason: "StayDuo: keep system awake"
            )
        case .screenOffKeepNet:
            try create(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                reason: "StayDuo: keep network while display sleeps"
            )
        }
    }

    func releaseAll() {
        for id in assertionIDs {
            IOPMAssertionRelease(id)
        }
        assertionIDs.removeAll()
    }

    deinit {
        releaseAll()
    }

    private func create(type: CFString, reason: String) throws {
        var assertionID = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        guard status == kIOReturnSuccess else {
            throw AssertionError.createFailed(String(describing: type), status)
        }
        assertionIDs.append(assertionID)
    }
}

enum AssertionError: LocalizedError {
    case createFailed(String, IOReturn)

    var errorDescription: String? {
        switch self {
        case .createFailed(let type, let status):
            return "无法创建电源断言 \(type)（IOReturn \(status)）"
        }
    }
}
