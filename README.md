# wx-tablet-mode (微信安卓平板模式辅助与环境治理套件)

> **微信安卓平板副设备登录的外观伪装、官方底包校验、第一方登录 Hook 与运行环境治理套件**  
> Appearance disguise, official APK verification, first-party pad-login hook, and environment governance toolkit for running WeChat in secondary Android tablet mode.

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
- [🤝 兄弟项目 (Sibling Projects)](#-兄弟项目-sibling-projects)
- [🙏 致谢 (Credits)](#-致谢-credits)
- [🔒 安全政策与免责声明](#-安全政策与免责声明)
- [📄 开源许可证](#-开源许可证)
- [💬 交流群 (Community)](#-交流群-community)

---

### ⚠️ 核心前置声明与项目边界

> **重要声明 (Crucial Prerequisite & Boundary)**：  
> 1. **内置第一方 Pad 登录资格 Hook (v1.0.2+)**：自 `v1.0.2` 起，本项目实现**真正自包含**——在开源模块中内置了纯开源、干净实现的 `PadLoginHook`（基于 LuckyPray/DexKit 动态特征匹配）。它动态定位并拦截微信平板环境检测（`inTabletEnv`）与副设备扫码预检协程（`checkloginaspad`），**单 APK 即可完整赋予平板扫码同登资格，彻底无需任何未授权或闭源第三方 APK**。  
> 2. **本项目包含什么**：开源模块 `com.wx.pad` 同时包含外观与断点伪装（`PadDisguise`，伪装 `sw600dp` 与强制竖屏锁定）与副设备登录资格赋予（`PadLoginHook`），并配套提供官方底包哈希校验、白纸认证态重置与守护自愈脚本。外部第三方 Hook 现已转为**完全可选的兼容项**（若偏好使用外部 Hook，可通过系统属性 `persist.wx.pad.loginhook 0` 随时切换，详见 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)）。  
> 3. **数据导出伴侣**：如需只读导出微信聊天记录接入 AI 助理，请搭配使用兄弟项目 [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter)。  
> 4. **法律与合规诚实声明**：本项目属于个人设备上的系统适配与逆向工程研究，**绝不分发或修改任何微信专有二进制，亦不包含任何第三方专有代码**。模块在运行时 Hook 商业专有软件，仅供使用者在个人合法拥有的硬件与账号上用于学习与研究；使用者须自行对遵守《微信个人账号使用规范》与服务条款承担全部责任。  
> 5. **物理安卓平板同样需要 Root（关键说明）**：本项目所有能力（`PadDisguise`、`PadLoginHook`、认证态治理、数据导出伴侣）均以 Xposed/LSPosed 模块形态运行，底层强依赖 Root（Magisk 或 KernelSU）+ Zygisk + LSPosed/Vector。即便是一台“原生支持微信平板副设备登录”的物理安卓平板，本项目模块**仍必须运行在已 Root 的设备上**才能生效；**若平板未 Root，整套流水线将无法部署。**

### 📋 完整前置条件清单 (Complete Prerequisites)

> 💡 **单 APK 自包含方案**：v1.0.2+ 已内置第一方 Pad 登录资格 Hook，只需安装本仓库的单一 APK。第三方外部 Hook 变为可选兼容项。详见 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)。

| # | 前置条件 | 说明 / 验证 |
| :--- | :--- | :--- |
| ① | **已 Root 的安卓设备** | Magisk 27.0+ 或 KernelSU；`adb shell su -c id` 返回 `uid=0`。物理平板也**必须 Root**，否则模块无法安装。 |
| ② | **Zygisk + LSPosed 或 Vector** | 推荐 Vector v2.2+（API-102，无参构造 `XposedModule()`）；旧版 LSPosed (API-100) 亦受支持。二者只保留其一，避免 Zygote 竞争崩溃。 |
| ③ | **官方微信 `8.0.78 / 0x28004e32`** | MD5 `846b411199ae49d335d31b3a17036440`；SHA-256 `41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba`。Beta 版（`0x28004e38`）会被服务端拦截。 |
| ④ | **平板登录资格 Hook（✅ 已内置，无需第三方）** | **内置于当前模块 `com.wx.pad`**（`PadLoginHook`）。安装本模块并勾选 `com.tencent.mm` 作用域即可自动生效。亦支持保留用户自选的外部 Hook。 |
| ⑤ | **（可选）数据导出伴侣仓库** | 仅当你需要把聊天流只读导出到 AI 助理时，再搭配 [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter)。与登录资格无关。 |

> 🤖 **交给 AI Agent 自动部署？** 本仓库提供 [`AGENT.md`](AGENT.md)：你只需 Root 设备、开启 USB 调试、插上电脑，然后让任意具备 shell 权限的编码 Agent（omp / Claude Code / Codex）读取并执行 [`AGENT.md`](AGENT.md) 即可端到端自动完成部署与校验。

---

### ⚡ 30 秒极速上手 (Quickstart)

> **极速路径**：无需配置 Gradle 开发环境，直接下载预编译产物即可在 30 秒内装配就绪。

#### 步骤 1：下载预编译 APK
前往 [GitHub Releases 最新发布页](https://github.com/yaping-pro/wx-tablet-mode/releases/latest) 下载：
- `wx-tablet-mode-v1.0.2-universal.apk`

#### 步骤 2：安装并激活 Xposed 模块
```bash
# 1. 安装模块至设备
adb install -r wx-tablet-mode-v1.0.2-universal.apk

# 2. 在 LSPosed 或 Vector 管理器中：
#    - 启用 "com.wx.pad" (WX Tablet Mode) 模块
#    - 将目标微信 "com.tencent.mm" 勾选加入作用域 (Scope)
```

> **提示**：内置的 `PadLoginHook` 默认启用，无需额外安装任何第三方 Hook 即可直接获得扫码登录资格！若您偏好使用自己专属的外部 Hook，可随时通过 `su -c 'setprop persist.wx.pad.loginhook 0'` 关闭内置 Hook。

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
强制停止并重新打开微信，在登录界面即可选择作为平板设备登录（扫码登录），用主力手机扫码即可实现双设备同号同时在线！
> 📖 **完整端到端分步手册（从已 Root 手机到可用扫码登录）**：请直接查阅权威 SOP [`docs/TABLET_LOGIN_SOP.md`](docs/TABLET_LOGIN_SOP.md)。交给 Agent 自动执行见 [`AGENT.md`](AGENT.md)。

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
| **第一方登录资格 Hook (`PadLoginHook`)** | ✅ **包含** | 基于 DexKit 动态扫描并拦截环境检测与登录协程，实现自包含副设备登录 |
| **运维与自愈工具** | ✅ 包含 | 提供 Tinker 热更补丁隔离、认证态白纸重置及多用户环境自检 |
| **外部协议 Hook 兼容模式** | ✅ 包含 | 具备系统属性软开关，可平滑回退至第三方 Hook（详见 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)） |
| **聊天记录嗅探 / AI 导出** | ❌ **不包含** | 独立数据管道请参阅 [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter) |
| **微信专有二进制分发** | ❌ **不包含** | 绝不分发修改版或专有微信底包，详见 [`NO_PROPRIETARY_BINARIES.md`](NO_PROPRIETARY_BINARIES.md) |

---

### ❓ 常见问题与排错指南 (FAQ)

#### Q1: 打开微信直接跳出账号密码/手机号登录，为什么没有出现扫码登录界面？
**A**: 说明 Hook 尚未正确注入或未命中。请按以下顺序排查：
1. 模块 `com.wx.pad` 是否已在 LSPosed / Vector 管理器中启用；
2. 作用域 (Scope) 是否已勾选 `com.tencent.mm`；
3. 是否误将内置资格 Hook 停用（检查 `adb shell getprop persist.wx.pad.loginhook`，若为 `0` 则可通过 `setprop persist.wx.pad.loginhook 1` 重新启用）；
4. 如果微信运行在多用户/分身空间下（如 User 999），模块是否已映射至该空间（执行 `pm install-existing --user <UID> com.wx.pad`）。

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
- [🤖 AI Agent 自动化部署 Runbook (AGENT.md)](AGENT.md)
- [登录成功验收判据与日志特征](docs/TABLET_LOGIN_SUCCESS.md)
- [内置与外部协议 Hook 技术规范](docs/EXTERNAL_HOOK_SPEC.md)
- [双模块共存分析与开关配置说明](docs/COEXIST_ANALYSIS.md)
- [完整故障排查手册 (Troubleshooting)](docs/TROUBLESHOOTING.md)
- [框架与系统兼容性说明](docs/COMPATIBILITY.md)
- [非专有二进制分发声明](NO_PROPRIETARY_BINARIES.md)

---

### 🙏 致谢 (Credits)

本项目在研发与设计过程中汲取并采用了以下优秀开源项目的成果与思路，特此致谢：
- **[Houvven/I-Am-Pad](https://github.com/Houvven/I-Am-Pad)** (GPL-3.0) by Houvven：提供了优秀的平板模式 DexKit 靶点设计参考，为第一方纯开源自包含方案奠定了关键基础。
- **[LuckyPray/DexKit](https://github.com/LuckyPray/DexKit)** (LGPL-3.0) by LuckyPray：强大的 Android 运行时高性能 Dex 字节码动态匹配与解析引擎。
- **[rovo89 / XposedBridge](https://github.com/rovo89/XposedBridge)** (Apache-2.0)：经典 Xposed 运行时接口标准。


### 🤝 兄弟项目 (Sibling Projects)

本项目是微信个人数据自主权与本地 AI 助理工具套件的一部分：

| 项目 | 说明 | 状态 / 链接 |
| :--- | :--- | :--- |
 | **`wx-tablet-mode`** (本仓库) | 微信安卓平板模式辅助与环境治理套件（外观伪装 + 内置第一方平板登录资格 Hook，单 APK 自包含） | [yaping-pro/wx-tablet-mode](https://github.com/yaping-pro/wx-tablet-mode) |
| **`wx-pad-exporter`** | Pad 版微信实时聊天流只读导出守护进程 + 通用 Webhook / 个人 AI 助理数据管道（Xposed 探针 + Go 守护进程） | [yaping-pro/wx-pad-exporter](https://github.com/yaping-pro/wx-pad-exporter) |
| **`wx-linux-exporter`** | Linux 原生 / 容器化微信导出管道（Linux 端微信消息只读导出与助理桥接） | [yaping-pro/wx-linux-exporter](https://github.com/yaping-pro/wx-linux-exporter) |


### 🔒 安全政策与免责声明

- [安全政策与漏洞披露流程 (SECURITY.md)](SECURITY.md)
- [开源免责声明 (DISCLAIMER.md)](DISCLAIMER.md)
- [贡献指南 (CONTRIBUTING.md)](CONTRIBUTING.md)
---

### 📄 开源许可证

本项目核心源码与构建脚本依据 **[GNU General Public License v3.0 (GPL-3.0)](LICENSE)** 获得许可。  
第三方组件版权与授权细节请参阅项目根目录下的 **[NOTICE](NOTICE)** 文件。

---

## 💬 交流群 (Community)

<img src="assets/wechat-group-qr.png" alt="微信个人助理交流 群二维码" width="220" />

**群名称**：`微信个人助理交流`

> ⏳ **有效期提示**：本群二维码为微信临时群码，**有效期有限，目前有效至 2026-10-20**。过期后将无法扫码加入。仓库维护者会在群码轮换时**替换 `assets/wechat-group-qr.png`**（单文件替换即可），请始终以本仓库最新提交的图片为准。若二维码已过期，请前往仓库 [Issues](https://github.com/yaping-pro/wx-tablet-mode/issues) 反馈，或查看 `assets/wechat-group-qr.png` 的最新提交版本。

> 🛠️ **维护者须知**：当群码轮换时，直接将 `assets/wechat-group-qr.png` 替换为最新的群二维码图片（同名覆盖），并更新上方有效期日期即可，无需改动其他文件。

---

## English

### Table of Contents
- [⚠️ Core Prerequisite & Project Boundary](#️-core-prerequisite--project-boundary)
- [⚡ 30-Second Quickstart](#-30-second-quickstart)
- [🛠️ Build from Source](#️-build-from-source)
- [📦 Scope & Capability Positioning](#-scope--capability-positioning)
- [❓ FAQ & Troubleshooting](#-faq--troubleshooting)
- [📚 Documentation Index](#-documentation-index)
- [🤝 Sibling Projects](#-sibling-projects)
- [🙏 Credits](#-credits)
- [🔒 Security & Disclaimer](#-security--disclaimer)
- [📄 License](#-license)
- [💬 Community](#-community)

---

### ⚠️ Core Prerequisite & Project Boundary

> **Crucial Notice (Prerequisite & Scope Boundary)**:  
> 1. **First-Party Pad Login Hook Built-In (v1.0.2+)**: Starting with `v1.0.2`, this repository is **genuinely self-contained** — shipping our own clean-room, GPL-3.0 implementation of `PadLoginHook` (powered dynamically by LuckyPray/DexKit). It intercepts WeChat's tablet environment check (`inTabletEnv`) and secondary-device pre-qualification coroutine (`checkloginaspad`) at runtime, granting tablet QR scan-login eligibility in a **single APK with zero dependency on unlicensed third-party binaries**.  
> 2. **What this repository provides**: The open-source `com.wx.pad` module provides BOTH appearance disguise (`PadDisguise`, `sw600dp` breakpoint and portrait locking) AND pad-login qualification (`PadLoginHook`), alongside official APK verification and self-healing governance scripts. Third-party external hooks are now **entirely optional** (and can be toggled via `persist.wx.pad.loginhook 0`; see [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)).  
> 3. **Chat Stream Export**: For read-only chat export to AI assistants, see companion project [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter).  
> 4. **Legal & Compliance Honesty**: This project is personal technical research into Android system adaptation and runtime hooking on personal hardware. **It distributes zero proprietary WeChat binaries and zero closed-source third-party binaries.** Hooking commercial proprietary applications carries account risk; users are solely responsible for compliance with WeChat Terms of Service.  
> 5. **A physical Android tablet STILL needs Root**: Every capability in this project runs as an Xposed/LSPosed module, which fundamentally requires Root (Magisk or KernelSU) + Zygisk + LSPosed/Vector. Even on a physical tablet, this module **must run on a rooted device** to be installed; **an unrooted tablet cannot deploy the pipeline.**

### 📋 Complete Prerequisites

> 💡 **Self-Contained Single APK**: v1.0.2+ includes the first-party pad-login hook out of the box. Installing our single APK gives you both disguise and login entitlement. External hooks are optional. See [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md).

| # | Prerequisite | Notes / Verification |
| :--- | :--- | :--- |
| ① | **Rooted Android device** | Magisk 27.0+ or KernelSU; `adb shell su -c id` returns `uid=0`. A physical tablet **must also be rooted**, or the module cannot be installed. |
| ② | **Zygisk + LSPosed or Vector** | Vector v2.2+ (API-102, no-arg `XposedModule()`) recommended; legacy LSPosed (API-100) also supported. Keep only one active to avoid Zygote injection races. |
| ③ | **Official WeChat `8.0.78 / 0x28004e32`** | MD5 `846b411199ae49d335d31b3a17036440`; SHA-256 `41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba`. The Beta build (`0x28004e38`) is rejected by the server. |
| ④ | **Pad-login hook (✅ Built-in, no third-party APK needed)** | **Built directly into `com.wx.pad`** (`PadLoginHook`). Simply install our module and enable scope for `com.tencent.mm`. Users may still bring their own external hook if preferred. |
| ⑤ | **(Optional) companion export repo** | Only if you want to read-only export chat streams to an AI assistant, pair with [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter). Unrelated to login entitlement. |

> 🤖 **Hand setup to an AI agent?** This repo ships [`AGENT.md`](AGENT.md): just root the device, enable USB debugging, plug it in, then let any shell-capable coding agent (omp / Claude Code / Codex) read and execute [`AGENT.md`](AGENT.md) to complete the whole deployment and verification end-to-end.

---

### ⚡ 30-Second Quickstart

> **Shortest Path**: Skip Gradle compilation and set up everything within 30 seconds using prebuilt release assets.

#### Step 1: Download Prebuilt APK
Visit the [GitHub Releases Latest Page](https://github.com/yaping-pro/wx-tablet-mode/releases/latest) and download:
- `wx-tablet-mode-v1.0.2-universal.apk`

#### Step 2: Install & Enable Xposed Module
```bash
# 1. Install module APK onto target device
adb install -r wx-tablet-mode-v1.0.2-universal.apk

# 2. Inside LSPosed or Vector Manager:
#    - Enable "com.wx.pad" (WX Tablet Mode)
#    - Add target WeChat "com.tencent.mm" to its Scope
```

> **Notice**: The built-in `PadLoginHook` is active by default. No additional third-party hook is needed to get the QR login screen! If you prefer your own external hook, disable the built-in hook anytime via `su -c 'setprop persist.wx.pad.loginhook 0'`.

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
Force-stop and re-open WeChat. The interface will display a tablet dual-pane layout with a tablet login QR code. Scan the QR code using your primary mobile device to authorize tablet-mode coexistence!
> 📖 **Authoritative 5-Step SOP**: See [`docs/TABLET_LOGIN_SOP.md`](docs/TABLET_LOGIN_SOP.md). Handing setup to an AI Agent? See [`AGENT.md`](AGENT.md).

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
| **First-Party Pad Login Hook (`PadLoginHook`)** | ✅ **Included** | Dynamic DexKit matchers for environment and CGI pre-qualification checks |
| **Governance & Self-Healing Tooling** | ✅ Included | Tinker patch isolation, clean-slate auth reset, and multi-user preflight |
| **External Protocol Hook Compatibility** | ✅ Included | System property toggles allow smooth fallback to user-supplied hooks |
| **Chat Stream Sniffing & AI Pipeline** | ❌ **Excluded** | Dedicated export pipeline is handled in [`wx-pad-exporter`](https://github.com/yaping-pro/wx-pad-exporter) |
| **Proprietary WeChat Binary Distribution** | ❌ **Excluded** | Strictly distributes zero modified WeChat APKs; see [`NO_PROPRIETARY_BINARIES.md`](NO_PROPRIETARY_BINARIES.md) |

---

### ❓ FAQ & Troubleshooting

#### Q1: WeChat launches directly into phone number/password login without a QR code?
**A**: The qualification hook is inactive or not loaded. Verify:
1. That `com.wx.pad` is enabled in Vector / LSPosed Manager and `com.tencent.mm` is in its scope;
2. That the built-in hook was not inadvertently disabled (`adb shell getprop persist.wx.pad.loginhook`; if `0`, re-enable via `setprop persist.wx.pad.loginhook 1`);
3. If running inside a secondary profile or clone user (e.g. MIUI User 999), map the package: `pm install-existing --user <UID> com.wx.pad`.

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
- [🤖 AI Agent Autonomous Runbook (AGENT.md)](AGENT.md)
- [Login Acceptance Criteria & Log Signatures](docs/TABLET_LOGIN_SUCCESS.md)
- [Built-in & External Protocol Hook Specification](docs/EXTERNAL_HOOK_SPEC.md)
- [Dual-Module Coexistence & Toggle Configuration](docs/COEXIST_ANALYSIS.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Framework & System Compatibility Notes](docs/COMPATIBILITY.md)
- [No Proprietary Binaries Statement](NO_PROPRIETARY_BINARIES.md)

---

### 🙏 Credits

We gratefully acknowledge the following open-source projects and their contributors:
- **[Houvven/I-Am-Pad](https://github.com/Houvven/I-Am-Pad)** (GPL-3.0) by Houvven: Pioneered the DexKit matcher architecture and CGI interception design for WeChat tablet mode.
- **[LuckyPray/DexKit](https://github.com/LuckyPray/DexKit)** (LGPL-3.0) by LuckyPray: High-performance runtime Dex parsing and bytecode query engine.
- **[rovo89 / XposedBridge](https://github.com/rovo89/XposedBridge)** (Apache-2.0): Foundational Xposed framework API.


### 🤝 Sibling Projects

This repository is part of a toolkit suite for WeChat personal data sovereignty and local AI assistant pipelines:

| Project | Description | Link |
| :--- | :--- | :--- |
 | **`wx-tablet-mode`** (this repo) | Android tablet-mode coexistence toolkit with built-in first-party pad-login hook & appearance disguise (self-contained single APK). | [yaping-pro/wx-tablet-mode](https://github.com/yaping-pro/wx-tablet-mode) |
| **`wx-pad-exporter`** | Read-only realtime chat stream exporter daemon & universal assistant webhook bridge for tablet-mode WeChat (Xposed hook + Go daemon). | [yaping-pro/wx-pad-exporter](https://github.com/yaping-pro/wx-pad-exporter) |
| **`wx-linux-exporter`** | Linux-native / containerized WeChat chatstream exporter pipeline & assistant bridge. | [yaping-pro/wx-linux-exporter](https://github.com/yaping-pro/wx-linux-exporter) |


### 🔒 Security & Disclaimer

- [Security Policy (SECURITY.md)](SECURITY.md)
- [Disclaimer (DISCLAIMER.md)](DISCLAIMER.md)
- [Contributing Guidelines (CONTRIBUTING.md)](CONTRIBUTING.md)
---

### 📄 License

The core source code of `wx-tablet-mode` is licensed under the **[GNU General Public License v3.0 (GPL-3.0)](LICENSE)**.  
For third-party components, dependencies, and license notices, see **[NOTICE](NOTICE)**.

---

## 💬 Community

<img src="assets/wechat-group-qr.png" alt="WeChat Personal Assistant Community group QR" width="220" />

**Group name**: `微信个人助理交流` (WeChat Personal Assistant Community)

> ⏳ **Expiry notice**: This is a WeChat temporary group QR code with **limited validity — currently valid until 2026-10-20**. It will stop working after expiry. The maintainer refreshes this file (`assets/wechat-group-qr.png`) by swapping in the newest group QR when it rotates, so always rely on the latest committed image in this repo. If the QR has expired, please open an [Issue](https://github.com/yaping-pro/wx-tablet-mode/issues) or check `assets/wechat-group-qr.png` for the latest committed version.

> 🛠️ **Maintainer note**: When the group code rotates, simply replace `assets/wechat-group-qr.png` with the newest group QR image (same filename) and update the validity date above. No other files need to change.
