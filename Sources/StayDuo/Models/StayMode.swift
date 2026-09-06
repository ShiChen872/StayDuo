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
            return "屏幕不灭，系统不睡。下载、跑任务、开会都适用。"
        case .screenOffKeepNet:
            return "允许按系统设置熄屏，但电脑保持唤醒，Wi-Fi / 有线网不断开。"
        }
    }

    var menuBarText: String {
        switch self {
        case .screenOn:
            return "亮"
        case .screenOffKeepNet:
            return "网"
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
