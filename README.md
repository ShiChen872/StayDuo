# StayDuo

本地 macOS 菜单栏应用：开着的时候默认**屏幕不灭**，也可以改成**允许熄屏但不断网**。

适合 MacBook Pro（含 M 系列 / M5）。原理是 IOKit 电源断言，和系统自带的 `caffeinate` 同类，只在本应用运行期间生效。退出即恢复系统自己的休眠设置。

<p align="left">
  <img src="Resources/AppIcon-1024.png" width="128" height="128" alt="StayDuo icon">
</p>

A tiny menu-bar utility for Mac: keep the display awake, or let the screen sleep while the Mac (and its network) stays up.

## 功能

- 菜单栏常驻；点图标打开面板
- **常亮屏幕**（默认）：阻止空闲熄屏和系统睡眠
- **息屏不断网**：允许按系统设置熄屏，但电脑保持唤醒，Wi-Fi / 有线不断开
- 面板右上角开关可暂停；退出应用后释放断言
- 「登录时启动」（需安装到 `~/Applications`）
- 选择与开关会记在本机，下次打开沿用

菜单栏缩写：`亮` = 常亮屏幕，`网` = 息屏不断网，`关` = 已暂停。

## 两种模式

| 模式 | 屏幕 | 系统睡眠 | 网络 | 对应断言 |
|------|------|----------|------|----------|
| 常亮屏幕 | 不灭 | 不睡 | 不断 | `PreventUserIdleDisplaySleep` + `PreventUserIdleSystemSleep` |
| 息屏不断网 | 可按系统设置熄灭 | 不睡 | 不断 | `PreventUserIdleSystemSleep` |

「息屏不断网」解决的是：屏幕暗了以后，系统接着睡过去、Wi-Fi 掉线。StayDuo 只拦住**空闲系统睡眠**，屏幕仍可按「系统设置 → 电池 / 节能」里的时间熄灭。

## 安装

需要 macOS 14+，以及 [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/)（Swift 6）。

```bash
git clone https://github.com/ShiChen872/StayDuo.git
cd StayDuo
chmod +x script/build_and_run.sh
./script/build_and_run.sh debug --run
```

脚本会构建、安装到 `~/Applications/StayDuo.app`（启动前退出旧进程），然后打开。

```bash
# 只安装，不启动
./script/build_and_run.sh
open ~/Applications/StayDuo.app

# 冒烟测试：创建 / 切换 / 释放断言
swift build && .build/debug/StayDuo --smoke-test
```

登录时启动：把应用装进 `~/Applications` 后，在面板里勾选「登录时启动」。若系统提示批准，到 **系统设置 → 通用 → 登录项** 打开即可。

## 使用

1. 启动后菜单栏出现太阳（常亮）或 Wi-Fi（息屏不断网）图标。
2. 点图标：右上角开关打开 = 正在保持唤醒；关掉则暂停。
3. 点选两种模式之一；暂停时点某个模式会同时重新打开。
4. 不需要时点「退出」。断言随进程释放，系统恢复原样。

确认断言是否生效：

```bash
pmset -g assertions | grep StayDuo
```

常亮时应看到 `PreventUserIdleDisplaySleep` 和 `PreventUserIdleSystemSleep`；息屏不断网只应看到后者。

## 限制（M 系列）

- **合上盖仍会睡眠。** 这是 Apple Silicon 的默认策略，菜单栏应用改不了。外接显示器并接电源的开盖（clamshell）模式除外。
- 不会改系统全局的 `pmset` 休眠时间，只在 StayDuo 运行时持有断言。
- 常亮会更耗电；长时间挂机更适合「息屏不断网」。
- 需要管理员权限的全局节能项、合盖不睡等，不在本应用范围内。

## 项目结构

```text
Sources/StayDuo/
  App/         MenuBarExtra 入口、冒烟测试
  Models/      双模式
  Services/    IOKit 断言、登录项
  Stores/      开关、模式、本机偏好
  Views/       菜单栏标签与下拉面板
script/
  build_and_run.sh        构建并装到 ~/Applications
  generate_app_icon.swift 代码手绘图标（太阳 + Wi-Fi 弧）
  make_icns.py            生成 AppIcon.icns
```

## 隐私

- 不上网、不采集数据。
- 偏好写在本机 `UserDefaults`（`stayduo.enabled` / `stayduo.mode`）。
- 不需要辅助功能、屏幕录制或完全磁盘访问权限。

## License

MIT
