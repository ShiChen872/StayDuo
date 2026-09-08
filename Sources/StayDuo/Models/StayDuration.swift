import Foundation

enum StayDuration: String, CaseIterable, Identifiable {
    case indefinite
    case minutes15
    case minutes30
    case hours1
    case hours2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indefinite: return "无限"
        case .minutes15: return "15分"
        case .minutes30: return "30分"
        case .hours1: return "1小时"
        case .hours2: return "2小时"
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hours1: return 60 * 60
        case .hours2: return 2 * 60 * 60
        }
    }
}

enum BatteryAlert: Equatable {
    case none
    case warning
    case critical
}

struct BatteryStatus: Equatable {
    var percent: Double
    var isCharging: Bool
    var isOnBattery: Bool
    var minutesToEmpty: Int?

    var lineText: String {
        var parts = ["电池 \(Int(percent.rounded()))%"]
        if isCharging {
            parts.append("充电中")
        } else if isOnBattery, let minutes = minutesToEmpty, minutes > 0 {
            parts.append(Self.formatMinutes(minutes))
        } else if isOnBattery {
            parts.append("使用电池")
        } else {
            parts.append("电源适配器")
        }
        return parts.joined(separator: " · ")
    }

    static func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let rem = minutes % 60
            if rem == 0 {
                return "约 \(hours) 小时"
            }
            return "约 \(hours) 小时 \(rem) 分"
        }
        return "约 \(minutes) 分钟"
    }
}
