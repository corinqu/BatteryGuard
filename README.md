# BatteryGuard 🔋🛡️

<p align="center">
  <b>A lightweight, ultra-efficient battery health & charge management utility for Apple Silicon MacBooks.</b><br>
  <i>Ideal for users who don't want to upgrade to macOS 26, don't want to pay for commercial bloatware, and demand peak energy efficiency.</i><br>
  专为 Apple Silicon MacBook 设计的高能效电池健康管理工具 — 自定义充电上限，延长电池使用寿命；<b>适合不愿意升级 macOS 26 且不想使用付费软件、追求极致能效与轻量体验的 Mac 用户。</b>
</p>

<p align="center">
  <a href="#english">English</a> • <a href="#中文说明">中文说明</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M1%2FM2%2FM3%2FM4)-teal?style=flat-square" alt="Architecture">
  <img src="https://img.shields.io/badge/Dependencies-Zero%20(Standalone)-brightgreen?style=flat-square" alt="Dependencies">
  <img src="https://img.shields.io/badge/License-MIT-orange?style=flat-square" alt="License">
</p>

---

<span id="english"></span>

## English

### ✨ Key Features

- 🚀 **Zero Dependencies & Out-of-the-Box**: **No Homebrew or terminal commands needed**. The background privileged helper is completely embedded. Simply download, drag, and launch.
- 🔋 **Custom Charge Limit**: Freely set charge limits between 60% and 100% (break free from macOS's rigid 80% ceiling).
- ⚡ **Hardware-Level Auto Stop**: Stops charging automatically when the target percentage is reached, even while connected to MagSafe / USB-C power adapters.
- ⏬ **Active Natural Discharge**: If battery level exceeds your target, discharge down to the target percentage without physically unplugging the power adapter.
- 🎨 **1:1 Native macOS 15 Battery Icon**: Pixel-perfect vector icon matching macOS Sequoia's menu bar with smooth proportional fill. The subtle translucent gray lightning bolt appears **ONLY** when current is actively flowing into the battery.
- 🔢 **Customizable Menu Bar Display**: Toggle percentage numbers on/off, or switch to a minimalist **Numbers-Only** mode to save menu bar space.
- 📢 **Smart Notifications**: Rate-limited notifications (5-min interval guard) for limit reached and low battery warnings.
- 💚 **Deep Hardware Telemetry**: Read accurate cycle count and maximum capacity health percentage directly from Apple's `AppleSmartBattery` registers.
- 🗑️ **Foolproof One-Click Uninstall**: Menu bar uninstaller completely restores macOS factory charging defaults (100% limit, normal AC power), deregisters daemons, cleans files with **zero remnants**.
- 🪶 **Extreme Energy Efficiency**: Pure native Swift & AppKit, event-driven IOKit runloop wakeups. **0.0% idle CPU, ~3.5MB RAM footprint**.

---

### 📦 Installation

#### Method 1: Download DMG (Recommended)

1. Download the latest **`BatteryGuard-1.1.1.dmg`** from [Releases](../../releases).
2. Open the DMG file and drag **BatteryGuard** into your **Applications** folder.
3. Open BatteryGuard from Launchpad or Applications. On first launch, enter your Mac administrator password once to authorize the background helper service.
4. The battery icon will appear on your menu bar. Ready to use!

#### Method 2: Build from Source

```bash
# Clone repository
git clone https://github.com/corinqu/BatteryGuard.git
cd BatteryGuard

# Build and package DMG
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

---

### 🗑️ Uninstallation & Settings Restoration

BatteryGuard ensures a clean and complete uninstallation that leaves **zero trace** and automatically restores macOS default power management:

- **Method 1 (Recommended)**: Click the BatteryGuard menu bar icon → select **`🗑️ 卸载 BatteryGuard...` (Uninstall BatteryGuard)**. Confirm the prompts. The app automatically resets the SMC charge limit to 100%, enables power adapter passthrough, removes LaunchAgents, removes the privileged helper, and exits cleanly.
- **Method 2**: Double-click **`卸载 BatteryGuard.command`** in the DMG package or run `./scripts/uninstall.sh` in the terminal.

---

### 🔒 Safety & Compatibility

- **SIP Enabled**: Works completely with System Integrity Protection enabled.
- **Zero Kernel Extensions**: No third-party kexts, no modifications to the read-only system volume.
- **Fully Reversible**: Uses official SMC power management commands. Fully reset upon uninstallation, with **zero effect on hardware warranty**.

---

<span id="中文说明"></span>

## 中文说明

### ✨ 特性亮点

- 🚀 **开箱即用，零依赖**：**彻底脱离对 Homebrew 或任何终端命令的依赖**，底层充电服务组件已完全内置，真正做到普通用户双击即用。
- 🔋 **自定义充电上限**：自由设定 60% ~ 100% 充电阈值，告别 macOS 固定的 80% 限制。
- ⚡ **自动停充机制**：插着充电器到达设定电量时，SMC 硬件级停止供电。
- ⏬ **主动自然放电**：电量高于设定值时，无需物理拔线，一键切断充电输入并使用电池自然消耗至目标值。
- 🎨 **1:1 原生电池与智能闪电**：像素级复刻 macOS 15 动态电池图标，仅在**真正充入电流**时显示优雅的半透明冷灰闪电（插电但处于上限保护时不显示）。
- 🔢 **多样显示样式**：支持「原版电池图标（系统原生）」与「纯数字样式」自由切换，并可自选是否显示百分比。
- 📢 **系统级安全提醒**：电量达标通知与低电量警告，内置防刷屏防骚扰机制。
- 💚 **电池底层体检**：直接读取 AppleSmartBattery 底层健康度百分比与电池循环次数。
- 🗑️ **傻瓜化卸载与还原**：菜单栏一键完全还原系统原始充电状态（100% 不限制），并自动注销后台服务，实测零残留。
- 🪶 **极限能效与占用**：纯 Swift 原生打造，基于 IOKit RunLoop 事件源唤醒，**零定时器轮询，常驻内存仅 ~3-5MB，CPU 占用趋近 0%**。

---

### 📦 安装使用

#### 方式一：下载 DMG 安装包（推荐，开箱即用）

1. 从 [Releases](../../releases) 下载最新的 `BatteryGuard-1.1.1.dmg`。
2. 双击打开 DMG，将 **BatteryGuard** 拖入 **Applications**（应用程序）文件夹。
3. 从启动台打开 BatteryGuard，首次使用会弹出系统原生密码框，输入一次 Mac 登录密码授权后台服务即可。
4. 菜单栏右上角将出现电池图标，点击即可进行管理。无需任何终端或环境安装！

#### 方式二：源码构建

```bash
# 克隆仓库
git clone https://github.com/corinqu/BatteryGuard.git
cd BatteryGuard

# 编译并打包为 DMG
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

---

### 🗑️ 傻瓜化卸载指南

为了做到最纯净无残留的用户体验，BatteryGuard 提供了两种极简卸载方式，均会在卸载时**自动恢复所有电源管理设置为 macOS 原始状态**：

- **方式一：在 App 菜单栏内一键卸载（最方便）**：点击菜单栏上的 BatteryGuard 电池图标 → 选择 **「🗑️ 卸载 BatteryGuard...」**。程序将自动恢复充电上限为 100%、恢复适配器供电、移除开机自启、注销后台服务并清理自身。
- **方式二：使用 DMG 或仓库中的卸载脚本**：打开 DMG 或源码仓库，双击运行 **`卸载 BatteryGuard.command`**（或在终端运行 `./scripts/uninstall.sh`），根据提示一键完成清理与还原。

---

### 🔒 安全性说明

- **不关闭 SIP**（系统完整性保护开启下正常运行）。
- **不修改系统只读镜像**，不加载任何第三方内核扩展（kext）。
- **完全可逆**：底层调用 SMC 官方管理接口，卸载或设为 100% 后即与系统原生出厂状态一致，完全不影响硬件保修。

---

## 📄 License & Acknowledgements / 开源许可与致谢

### 📜 Project License / 本项目开源协议
- **BatteryGuard**: Licensed under the [MIT License](LICENSE).
- 本项目主体源码基于 [MIT 许可协议](LICENSE) 完全开源。

### 🤝 Third-Party Components & Credits / 第三方组件与致谢
- **[batt](https://github.com/charlie0129/batt)** (by [@charlie0129](https://github.com/charlie0129)):
  - BatteryGuard embeds and communicates with the `batt` daemon for low-level Apple Silicon SMC power management.
  - `batt` is distributed under the terms of the **GNU General Public License v2.0 (GPL-2.0)**.
  - Full license text: [Assets/bin/LICENSE_batt.txt](Assets/bin/LICENSE_batt.txt)
  - Upstream repository: [https://github.com/charlie0129/batt](https://github.com/charlie0129/batt)
  - *BatteryGuard 内置并调用了 charlie0129 开发的开源项目 `batt` 作为底层 SMC 充电管理守护进程。`batt` 遵循 GNU General Public License v2.0 (GPL-2.0) 开源协议，完整协议文件位于 [Assets/bin/LICENSE_batt.txt](Assets/bin/LICENSE_batt.txt)。衷心感谢原作者为 macOS 开源生态做出的杰出贡献！*

---

## ⚖️ Disclaimer / 免责与商标声明

- **Trademarks**: Apple, Mac, MacBook, MacBook Air, Apple Silicon, and macOS are trademarks of Apple Inc., registered in the U.S. and other countries. BatteryGuard is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Apple Inc.
  - *商标声明：Apple、Mac、MacBook、MacBook Air、Apple Silicon 及 macOS 均为 Apple Inc. 在美国及其他国家/地区的注册商标。BatteryGuard 为独立第三方开源工具，与 Apple 公司无任何隶属、合作或赞助关系。*
- **Warranty Disclaimer**: This software is provided "as is", without warranty of any kind, express or implied. BatteryGuard interacts with battery and power management hardware via official Apple SMC interfaces. While it has been thoroughly tested, users assume all risks associated with battery threshold customization.
  - *责任限制：本软件按“现状”提供，不包含任何明示或暗示的保证。BatteryGuard 通过 macOS 官方 SMC 接口实现充放电管理，虽已通过完备的硬件安全防呆测试，但用户仍需了解电源管理的基本原理。*
