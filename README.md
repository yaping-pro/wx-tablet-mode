# wx-tablet-mode (微信安卓平板模式辅助与环境治理套件)

> **微信安卓平板副设备登录的外观伪装、官方底包校验与运行环境治理套件**  
> Appearance disguise, official APK verification, and environment governance toolkit for running WeChat in secondary Android tablet mode.

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/yaping-pro/wx-tablet-mode?color=brightgreen)](https://github.com/yaping-pro/wx-tablet-mode/releases/latest)
[![Build APK](https://github.com/yaping-pro/wx-tablet-mode/actions/workflows/build-apk.yml/badge.svg)](https://github.com/yaping-pro/wx-tablet-mode/actions/workflows/build-apk.yml)

[中文](#中文) | [English](#english)

---

## 中文

### 目录
- [⚠️ 核心前置声明与项目边界](#-核心前置声明与项目边界)
- [⚡ 30 秒极速上手 (Quickstart)](#-30-秒极速上手-quickstart)
- [🛠️ 从源码构建](#️-从源码构建)
- [📦 仓库范围与功能定位](#-仓库范围与功能定位)
- [❓ 常见问题与排错指南 (FAQ)](#-常见问题与排错指南-faq)
- [📚 详细文档索引](#-详细文档索引)
- [🔒 安全政策与免责声明](#-安全政策与免责声明)
- [📄 开源许可证](#-开源许可证)

---

### ⚠️ 核心前置声明与项目边界

> **重要声明 (Crucial Prerequisite & Boundary)**：  
> 1. **本项目绝非登录资格授予工具**：微信服务端对“平板副设备扫码登录”的席位判决，**独家依赖外部协议 Hook**（如社区成熟方案 `com.roro.tablethook` 或用户自研 Hook）。  
> 2. **本项目包含什么**：开源模块 `PadDisguise` 仅负责屏幕断点（`sw600dp`）伪装与强制竖屏锁定，解决手机硬件上的界面排版走样、旋转错乱问题，并配套提供官方底包校验、白纸认证态重置与看门狗脚本。模块本身**不含任何登录资格授予逻辑**（详见 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)）。  
> 3. **数据导出伴侣**：如需只读导出微信聊天记录接入 AI 助理，请搭配使用兄弟项目 [`wechat-pad-exporter`](https://github.com/yaping-pro/wechat-pad-exporter)。

---

### ⚡ 30 秒极速上手 (Quickstart)

> **极速路径**：无需配置 Gradle 开发环境，直接下载预编译产物即可在 30 秒内装配就绪。

#### 步骤 1：下载预编译 APK
前往 [GitHub Releases 最新发布页](https://github.com/yaping-pro/wx-tablet-mode/releases/latest) 下载：
- `wx-tablet-mode-v1.0.1-universal.apk`

#### 步骤 2：安装并激活 Xposed 模块
```bash
# 1. 安装模块至设备
adb install -r wx-tablet-mode-v1.0.1-universal.apk

# 2. 在 LSPosed 或 Vector 管理器中：
#    - 启用 "com.wx.pad" (PadDisguise) 模块
#    - 将目标微信 "com.tencent.mm" 勾选加入作用域 (Scope)
```

> **注意 (外部 Hook 前置)**：请确保您已同时安装并启用了**外部协议 Hook**（如 `com.roro.tablethook`），并同样勾选了 `com.tencent.mm`。缺少协议 Hook 将直接跳出账号密码登录，而非扫码登录！

#### 步骤 3：环境自检与认证态重置 (可选但推荐)
若微信曾尝试登录失败导致认证态死锁，运行自带脚本一键自检与白纸化重置：
```bash
# 克隆仓库运行自检脚本
git clone https://github.com/yaping-pro/wx-tablet-mode.git
cd wx-tablet-mode

# 环境就绪检查 (Root / 框架 / 官方底包哈希)
bash scripts/preflight_check.sh

# 清理历史认证死锁并隔离静默下发的 Tinker 补丁
bash scripts/reset_wechat_auth.sh
bash scripts/quarantine_tinker.sh
```

#### 步骤 4：扫码登录
在手机上拉起微信，此时界面呈现标准平板排版并展示“平板登录二维码”，使用主力手机扫码授权即可完成双登！

---

### 🛠️ 从源码构建

如果您希望自行审计代码并编译 APK：

```bash
# 1. 准备构建环境 (需要 JDK 17+)
git clone https://github.com/yaping-pro/wx-tablet-mode.git
cd wx-tablet-mode

# 2. 执行 Gradle 构建
./gradlew assembleRelease

# 3. 输出路径
# app/build/outputs/apk/release/app-release.apk
```

---

### 📦 仓库范围与功能定位

| 模块 / 能力 | 归属状态 | 说明 |
| :--- | :---: | :--- |
| **官方底包校验 SOP** | ✅ 包含 | 提供 `8.0.78 / 0x28004e32` 正式版 SHA-256 哈希比对与来源验证 |
| **外观与断点伪装 (`PadDisguise`)** | ✅ 包含 | 伪装 `smallestScreenWidthDp >= 600`，锁定竖屏避免手机旋转变形 |
| **运维与自愈工具** | ✅ 包含 | 提供 Tinker 热更补丁隔离、认证态白纸重置及多用户环境自检 |
| **登录协议 Hook / 资格判决** | ❌ **不包含** | 需用户自备第三方协议 Hook（如 `com.roro.tablethook`） |
| **聊天记录嗅探 / AI 导出** | ❌ **不包含** | 独立数据管道请参阅 [`wechat-pad-exporter`](https://github.com/yaping-pro/wechat-pad-exporter) |
| **微信专有二进制分发** | ❌ **不包含** | 绝不分发破解版微信底包，详见 [`NO_PROPRIETARY_BINARIES.md`](NO_PROPRIETARY_BINARIES.md) |

---

### ❓ 常见问题与排错指南 (FAQ)

#### Q1: 打开微信直接跳出账号密码/手机号登录，为什么没有出现扫码登录界面？
**A**: 这是最典型的现象。说明**外部协议 Hook 尚未注入或未生效**。请检查：
1. 外部协议 Hook（如 `com.roro.tablethook`）是否已安装并在 Xposed/Vector 管理器中启用；
2. 作用域是否勾选了 `com.tencent.mm`；
3. 如果微信运行在多用户/分身空间下，外部模块是否已映射至该空间（执行 `pm install-existing --user <UID> com.roro.tablethook`）。

#### Q2: 扫码后提示“当前设备登录异常”或二维码不断刷新失败？
**A**: 通常是先前的登录流程中断导致认证态死锁（`auth_ishold=true`）。请运行：
```bash
bash scripts/reset_wechat_auth.sh
```
该脚本将安全移走受损的 `autoauth.cfg` 和 `auth_hold_prefs.xml`，恢复纯净白纸状态。

#### Q3: 提示“The beta version is only for eligible users”？
**A**: 微信后台静默下载了 Tinker 热修复补丁并将内部版本号抬升到了内测通道。请执行：
```bash
bash scripts/quarantine_tinker.sh
```
该脚本会将 Tinker 下载目录置空并锁定权限，阻止内测补丁加载。

#### Q4: 应用双开 / 多用户环境（如 MIUI 分身用户 999）如何正确定位 UID？
**A**: 绝不要盲目硬编码 `999`。请使用 Android 官方 dumpsys 动态查找目标用户的真实 UID：
```bash
TARGET_USER=999 # 替换为目标分身用户编号
dumpsys package --user "$TARGET_USER" com.tencent.mm 2>/dev/null | grep "userId=" | head -1 | awk -F= '{print $2}' | tr -d ' \r\n'
```
并在执行自检时传入参数：
```bash
TARGET_USER=999 bash scripts/preflight_check.sh
```

#### Q5: 执行 `pm install-existing --user <UID>` 报错找不到包？
**A**: `pm install-existing` 的前提是主用户（User 0）或系统底层中已经安装了该 APK。如果主空间从未安装过，必须先执行 `adb install <apk>`，然后再向特定分身空间映射。

#### Q6: 重启手机后微信无法自启或报错找不到数据目录？
**A**: Android 基于文件加密 (FBE)。开机后在用户首次输入锁屏密码前，凭据加密存储 (CE) 处于锁定状态。作为常驻副设备的备用机，建议在“开发者选项/安全设置”中取消锁屏密码，或开机后手动解锁一次。

---

### 📚 详细文档索引

- [权威 5 步扫码登录操作手册 (SOP)](docs/TABLET_LOGIN_SOP.md)
- [登录成功验收判据与日志特征](docs/TABLET_LOGIN_SUCCESS.md)
- [外部协议 Hook 依赖规范与靶点剖析](docs/EXTERNAL_HOOK_SPEC.md)
- [双模块共存分析与开关配置说明](docs/COEXIST_ANALYSIS.md)
- [完整故障排查手册 (Troubleshooting)](docs/TROUBLESHOOTING.md)
- [框架与系统兼容性说明](docs/COMPATIBILITY.md)
- [非专有二进制分发声明](NO_PROPRIETARY_BINARIES.md)

---

### 🔒 安全政策与免责声明

- [安全政策与漏洞披露流程 (SECURITY.md)](SECURITY.md)
- [开源免责声明 (DISCLAIMER.md)](DISCLAIMER.md)

---

### 📄 开源许可证

本项目基于 [GNU General Public License v3.0 (GPL-3.0)](LICENSE) 许可证开源。

---

## English

### Table of Contents
- [⚠️ Core Prerequisite & Project Boundary](#️-core-prerequisite--project-boundary)
- [⚡ 30-Second Quickstart](#-30-second-quickstart)
- [🛠️ Build from Source](#️-build-from-source)
- [📦 Scope & Capability Positioning](#-scope--capability-positioning)
- [❓ FAQ & Troubleshooting](#-faq--troubleshooting)
- [📚 Documentation Index](#-documentation-index)
- [🔒 Security & Disclaimer](#-security--disclaimer)
- [📄 License](#-license)

---

### ⚠️ Core Prerequisite & Project Boundary

> **Crucial Notice (Prerequisite & Scope Boundary)**:  
> 1. **NOT a Login Bypass or Entitlement Granting Tool**: WeChat server-side secondary tablet mode login entitlement relies **strictly on an external protocol Hook** (such as community module `com.roro.tablethook` or proprietary custom reverse-engineered hooks).  
> 2. **What this repository provides**: The open-source `PadDisguise` module solely provides layout breakpoint (`sw600dp`) disguise and portrait orientation locking to eliminate UI distortions and unintended rotations on smartphone screens. It contains **no login qualification logic** whatsoever (see [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)).  
> 3. **Chat Stream Export**: For read-only chat export to AI assistants, see the companion project [`wechat-pad-exporter`](https://github.com/yaping-pro/wechat-pad-exporter).

---

### ⚡ 30-Second Quickstart

> **Shortest Path**: Skip Gradle compilation and set up everything within 30 seconds using prebuilt release assets.

#### Step 1: Download Prebuilt APK
Visit the [GitHub Releases Latest Page](https://github.com/yaping-pro/wx-tablet-mode/releases/latest) and download:
- `wx-tablet-mode-v1.0.1-universal.apk`

#### Step 2: Install & Enable Xposed Module
```bash
# 1. Install module APK onto target device
adb install -r wx-tablet-mode-v1.0.1-universal.apk

# 2. Inside LSPosed or Vector Manager:
#    - Enable "com.wx.pad" (PadDisguise)
#    - Add target WeChat "com.tencent.mm" to its Scope
```

> **Prerequisite Reminder**: Ensure your **external protocol hook** (e.g. `com.roro.tablethook`) is installed and active with `com.tencent.mm` checked in scope as well. Without it, WeChat will display phone account/password login rather than tablet QR login!

#### Step 3: Run Preflight Check & Clean State Reset (Optional but Recommended)
If previous login attempts failed or hung, clean up lingering locks:
```bash
# Clone repository for governance scripts
git clone https://github.com/yaping-pro/wx-tablet-mode.git
cd wx-tablet-mode

# Check environment readiness (Root / Framework / Official APK hash)
bash scripts/preflight_check.sh

# Reset credentials and isolate silent Tinker hotfix patches
bash scripts/reset_wechat_auth.sh
bash scripts/quarantine_tinker.sh
```

#### Step 4: Scan QR Code to Log In
Launch WeChat. The interface will display a tablet dual-pane layout with a tablet login QR code. Scan the QR code using your primary mobile device to authorize tablet-mode coexistence!

---

### 🛠️ Build from Source

If you prefer compiling from source code directly:

```bash
# Requires JDK 17+
git clone https://github.com/yaping-pro/wx-tablet-mode.git
cd wx-tablet-mode

# Compile APK
./gradlew assembleRelease

# Output artifact:
# app/build/outputs/apk/release/app-release.apk
```

---

### 📦 Scope & Capability Positioning

| Feature / Capability | Scope Status | Description |
| :--- | :---: | :--- |
| **Official APK Verification SOP** | ✅ Included | Hash verification for official `8.0.78 / 0x28004e32` release |
| **Appearance Disguise (`PadDisguise`)** | ✅ Included | Disguises `smallestScreenWidthDp >= 600` and enforces portrait locking |
| **Governance & Self-Healing Tooling** | ✅ Included | Tinker patch isolation, clean-slate auth reset, and multi-user preflight |
| **Login Entitlement Hook** | ❌ **Excluded** | Must be provided separately via external hook (e.g. `com.roro.tablethook`) |
| **Chat Stream Sniffing & AI Pipeline** | ❌ **Excluded** | Dedicated export pipeline is handled in [`wechat-pad-exporter`](https://github.com/yaping-pro/wechat-pad-exporter) |
| **Proprietary WeChat Binary Distribution** | ❌ **Excluded** | Strictly distributes zero modified WeChat APKs; see [`NO_PROPRIETARY_BINARIES.md`](NO_PROPRIETARY_BINARIES.md) |

---

### ❓ FAQ & Troubleshooting

#### Q1: WeChat launches directly into phone number/password login without a QR code?
**A**: The external protocol hook is not injected or inactive. Verify:
1. That the external hook (e.g. `com.roro.tablethook`) is installed and enabled in Vector/LSPosed;
2. That `com.tencent.mm` is selected in its scope;
3. If running inside a secondary profile or clone user, map the package: `pm install-existing --user <UID> com.roro.tablethook`.

#### Q2: WeChat displays "Login error" or QR code fails to refresh?
**A**: Caused by aborted prior attempts leaving a lingering `auth_ishold=true` state. Run:
```bash
bash scripts/reset_wechat_auth.sh
```
This safely archives corrupt `autoauth.cfg` and `auth_hold_prefs.xml` files and restores a clean slate.

#### Q3: Error banner: "The beta version is only for eligible users"?
**A**: WeChat's background Tinker engine downloaded a beta hotfix patch. Run:
```bash
bash scripts/quarantine_tinker.sh
```
This empties and locks the patch directory against future downloads.

#### Q4: How to detect the exact UID in dual-app / clone environments (e.g. MIUI User 999)?
**A**: Never hardcode user ID `999`. Query the real assigned UID dynamically via dumpsys:
```bash
TARGET_USER=999 # Target secondary profile
dumpsys package --user "$TARGET_USER" com.tencent.mm 2>/dev/null | grep "userId=" | head -1 | awk -F= '{print $2}' | tr -d ' \r\n'
```
Pass the parameter when testing:
```bash
TARGET_USER=999 bash scripts/preflight_check.sh
```

#### Q5: `pm install-existing --user <UID>` fails with package not found?
**A**: `pm install-existing` requires the APK to already exist under User 0. If it has never been installed on the device, run `adb install <apk>` first.

#### Q6: WeChat fails to start after reboot?
**A**: Android File-Based Encryption (FBE) locks Credential Encrypted (CE) storage until first unlock. For an always-on dedicated secondary device, consider removing the lockscreen password in system settings or unlocking manually once after boot.

---

### 📚 Documentation Index

- [Authoritative 5-Step QR Login SOP](docs/TABLET_LOGIN_SOP.md)
- [Login Acceptance Criteria & Log Signatures](docs/TABLET_LOGIN_SUCCESS.md)
- [External Protocol Hook Specification & Hook Targets](docs/EXTERNAL_HOOK_SPEC.md)
- [Dual-Module Coexistence & Toggle Configuration](docs/COEXIST_ANALYSIS.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Framework & System Compatibility Notes](docs/COMPATIBILITY.md)
- [No Proprietary Binaries Statement](NO_PROPRIETARY_BINARIES.md)

---

### 🔒 Security & Disclaimer

- [Security Policy (SECURITY.md)](SECURITY.md)
- [Disclaimer (DISCLAIMER.md)](DISCLAIMER.md)

---

### 📄 License

Distributed under the [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
