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
            Text(store.host?.menuBarText ?? "C--·M--·D--")
                .monospacedDigit()
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color(for: lowestHealth))
        }
        .accessibilityLabel(accessibilityText)
    }

    private var lowestHealth: Double? {
        guard let host = store.host else { return nil }
        return min(host.cpuHealthPercent, host.memoryHealthPercent, host.diskHealthPercent)
    }

    private func color(for remaining: Double?) -> Color {
        guard let remaining else { return .secondary }
        if remaining > 50 { return .primary }
        if remaining > 10 { return Color(red: 1.0, green: 0.58, blue: 0.14) }
        return Color(red: 0.95, green: 0.35, blue: 0.35)
    }

    private var accessibilityText: String {
        let modeText = store.isEnabled ? store.mode.title : "已关闭"
        if let host = store.host {
            return "StayDuo \(modeText)，\(host.menuBarText)"
        }
        return "StayDuo \(modeText)"
    }
}
