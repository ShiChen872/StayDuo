import SwiftUI
import AppKit

struct StayPanelView: View {
    var store: StayStore
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginItemMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusCard
            modeList
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

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: store.isEnabled ? store.mode.systemImage : "moon.zzz")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var modeList: some View {
        VStack(spacing: 8) {
            ForEach(StayMode.allCases) { mode in
                Button {
                    store.mode = mode
                    if !store.isEnabled {
                        store.isEnabled = true
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: store.mode == mode && store.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.mode == mode && store.isEnabled ? statusColor : Color.secondary)
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(mode.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.primary.opacity(store.mode == mode && store.isEnabled ? 0.08 : 0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var note: some View {
        Text("合上盖仍会睡眠（M 系列默认）。外接显示器并接电源的开盖模式除外。退出应用后恢复系统自己的休眠设置。")
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
            if let lastError = store.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else {
                Text(store.isAssertionHeld ? "断言已生效" : "未持有断言")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private var statusTitle: String {
        if !store.isEnabled {
            return "已暂停"
        }
        return store.mode.title
    }

    private var statusDetail: String {
        if let lastError = store.lastError {
            return lastError
        }
        if !store.isEnabled {
            return "系统按自己的节能设置休眠。打开开关即可重新保持唤醒。"
        }
        return store.mode.subtitle
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
}
