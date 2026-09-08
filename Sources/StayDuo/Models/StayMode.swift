import Foundation

enum StayMode: String, CaseIterable, Identifiable {
    case screenOn
    case screenOffKeepNet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenOn:
            return "常亮屏幕"
        case .screenOffKeepNet:
            return "息屏不断网"
        }
    }

    var subtitle: String {
        switch self {
        case .screenOn:
            return "屏不灭，系统不睡"
        case .screenOffKeepNet:
            return "可熄屏，网不断"
        }
    }

    var systemImage: String {
        switch self {
        case .screenOn:
            return "sun.max.fill"
        case .screenOffKeepNet:
            return "wifi"
        }
    }
}
