import SwiftUI
import AppKit

struct StayPanelView: View {
    var store: StayStore
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginItemMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            batteryRow
            HostMetricsCard(metrics: store.host)
            modeList
            durationRow
            note
            settingsRow
            footer
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
        }
    }

    private var header: some View {
        HStack {
            Text("StayDuo")
                .font(.headline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.isEnabled },
                set: { store.isEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .help(store.isEnabled ? "暂停唤醒断言" : "恢复唤醒断言")
        }
    }

    @ViewBuilder
    private var batteryRow: some View {
        if let battery = store.host?.battery {
            HStack(spacing: 6) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 11, weight: .semibold))
                Text(battery.lineText)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(batteryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(batteryColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var modeList: some View {
        VStack(spacing: 6) {
            ForEach(StayMode.allCases) { mode in
                Button {
                    store.selectMode(mode)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: store.mode == mode && store.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.mode == mode && store.isEnabled ? statusColor : Color.secondary)
                            .font(.system(size: 14, weight: .semibold))
                        Text(mode.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(mode.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.primary.opacity(store.mode == mode && store.isEnabled ? 0.08 : 0.04),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var durationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("时长")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(StayDuration.allCases) { item in
                    Button {
                        store.selectDuration(item)
                    } label: {
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(
                                store.duration == item ? statusColor.opacity(0.18) : Color.primary.opacity(0.05),
                                in: Capsule()
                            )
                            .foregroundStyle(store.duration == item ? statusColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var note: some View {
        Text("合上盖仍会睡眠（M 系列默认）。外接显示器并接电源除外。")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var settingsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("登录时启动", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    if let error = LoginItemManager.setEnabled(newValue) {
                        loginItemMessage = error
                        launchAtLogin = LoginItemManager.isEnabled
                    } else {
                        loginItemMessage = nil
                        launchAtLogin = LoginItemManager.isEnabled
                        if launchAtLogin != newValue {
                            loginItemMessage = LoginItemManager.statusDescription
                        }
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)

            if let loginItemMessage {
                Text(loginItemMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(store.remainingDescription(now: context.date))
                    .font(.caption)
                    .foregroundStyle(store.lastError == nil ? Color.secondary : Color.orange)
            }
            Spacer()
            Button("退出") {
                store.release()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private var statusColor: Color {
        if !store.isEnabled {
            return .secondary
        }
        switch store.mode {
        case .screenOn:
            return Color(red: 1.0, green: 0.58, blue: 0.14)
        case .screenOffKeepNet:
            return Color(red: 0.18, green: 0.72, blue: 0.62)
        }
    }

    private var batteryColor: Color {
        switch store.batteryAlert {
        case .critical:
            return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .warning:
            return Color(red: 1.0, green: 0.58, blue: 0.14)
        case .none:
            return .secondary
        }
    }

    private var batteryIcon: String {
        guard let battery = store.host?.battery else { return "battery.100" }
        if battery.isCharging {
            return "battery.100.bolt"
        }
        if battery.percent >= 90 {
            return "battery.100"
        }
        if battery.percent >= 60 {
            return "battery.75"
        }
        if battery.percent >= 35 {
            return "battery.50"
        }
        if battery.percent > 15 {
            return "battery.25"
        }
        return "battery.0"
    }
}
