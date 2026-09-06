import SwiftUI

struct MenuBarStayGlyph: View {
    let enabled: Bool
    let mode: StayMode

    private var mint: Color { Color(red: 0.18, green: 0.95, blue: 0.72) }
    private var amber: Color { Color(red: 1.0, green: 0.58, blue: 0.14) }

    var body: some View {
        ZStack {
            if enabled && mode == .screenOn {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(amber)
            } else if enabled && mode == .screenOffKeepNet {
                Image(systemName: "wifi")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(mint)
            } else {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

struct MenuBarLabel: View {
    var store: StayStore

    var body: some View {
        HStack(spacing: 4) {
            MenuBarStayGlyph(enabled: store.isEnabled, mode: store.mode)
            Text(store.isEnabled ? store.mode.menuBarText : "关")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(store.isEnabled ? Color.primary : Color.secondary)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if store.isEnabled {
            return "StayDuo \(store.mode.title)"
        }
        return "StayDuo 已关闭"
    }
}
