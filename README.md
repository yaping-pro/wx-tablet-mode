# wx-tablet-mode (微信安卓平板模式辅助与环境治理套件)

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Build APK](https://github.com/steven/wx-tablet-mode/actions/workflows/build-apk.yml/badge.svg)](.github/workflows/build-apk.yml)

> ⚠️ **核心前置声明 (Core Prerequisite & Boundary)**:  
> 本项目是**微信安卓平板副设备登录的【方法论智库、官方包校验 SOP、环境治理脚本与外观伪装辅助件】**，**绝非登录资格授予工具**！  
> 微信服务端平板副设备登录席位的资格判决，**独家依赖外部协议 Hook**（如社区闭源 `com.roro.tablethook` 或用户自研逆向 Hook）。本项目自带的 `PadDisguise` 开源模块仅负责屏幕断点（`sw600dp`）伪装与强制竖屏锁定，解决手机硬件上的界面排版与旋转问题，**不含**任何登录资格授予逻辑。详细规范请参阅 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)。

---

## 脆弱性与维护生命周期预警 (Fragility & Lifecycle Notice)

> ⚠️ **高脆弱性警告**：  
> 本项目高度受制于腾讯服务端对 Pad 设备判决逻辑与微信客户端大版本的升级策略。微信通常在 6~12 个月内对陈旧客户端下发 `force_update` 强制升级指令。一旦 `8.0.78` 官方底包被服务端全面阻断，方案将面临版本失效风险，需社区持续逆向跟进新版本特征。

---

## 仓库范围与功能定位 (What it IS & What it is NOT)

### What it IS
1. **官方包校验 SOP 与干净认证态重置**：提供经过反复生产验证的官方正式版（`8.0.78 / 0x28004e32`）哈希比对与白纸认证态重置机制。
2. **开源外观与排版辅助模块 (`PadDisguise`)**：覆写 `Build.MODEL` 等设备标识，伪装 `smallestScreenWidthDp >= 600`，强制竖屏防止旋转错乱。
3. **一键就绪自检与环境运维脚本**：自动化检测 Root、Zygisk、Vector API-102 框架、Tinker 热修复隔离及安全回滚。

### What it is NOT
1. **绝不是登录资格授予工具**：必须搭配合法的外部协议 Hook 才能完成副设备扫码认证。
2. **绝不包含任何聊天数据嗅探或个人助理逻辑**：数据提取与导出属于独立项目生态。
3. **绝不包含或分发任何专有微信二进制**：不提供修改版 APK 或微信专有代码，详见 [`NO_PROPRIETARY_BINARIES.md`](NO_PROPRIETARY_BINARIES.md)。

---

## 快速上手 (Quick Start)

### 1. 前置条件 (Prerequisites)
- **已 Root 的 Android 设备**（Magisk 27+ 或 KernelSU）
- **Zygisk + Vector 框架**：推荐 **Vector v2.2+ (API-102)**，避免旧版 LSPosed API-100 反射构造异常。
- **官方微信正式版底包**：安装官方 `8.0.78` 正式版（SHA-256: `41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba`）。
- **外部协议 Hook 模块**：已自行获取并安装生效（如 `com.roro.tablethook`）。

### 2. 环境自检 (Preflight Check)
通过 USB 调试连接设备，运行环境就绪检查脚本：

```bash
# 检查主用户 (User 0)
bash scripts/preflight_check.sh

# 若使用应用分身/双开用户 (如 MIUI User 999)
TARGET_USER=999 bash scripts/preflight_check.sh
```

### 3. 安装外观辅助模块 (`PadDisguise`)
您可以在 GitHub Releases 直接下载预编译的 `com.wx.pad` APK，或自行构建：

```bash
# 本地 Gradle 构建
./gradlew assembleRelease
# 安装至设备
adb install -r app/build/outputs/apk/release/app-release.apk
```
安装后，在 Vector/LSPosed 管理器中将目标微信添加到模块作用域（Scope）。

### 4. 认证态白纸重置与登录 (Reset & Login)
若先前尝试登录曾遇阻或挂起，必须重置为白纸认证态以消除 `auth_ishold` 阻碍：

```bash
# 重置认证态（原凭据会自动安全备份）
bash scripts/reset_wechat_auth.sh

# 隔离微信后台静默下发的 Tinker Beta 补丁
bash scripts/quarantine_tinker.sh
```

随后拉起微信扫码登录页，使用主力机扫码授权即可完成平板模式双登！

---

## 文档索引 (Documentation)

- [权威 5 步扫码登录操作手册 (SOP)](docs/TABLET_LOGIN_SOP.md)
- [登录成功验收判据与日志特征](docs/TABLET_LOGIN_SUCCESS.md)
- [外部协议 Hook 依赖规范与靶点剖析](docs/EXTERNAL_HOOK_SPEC.md)
- [双模块共存分析与开关配置说明](docs/COEXIST_ANALYSIS.md)
- [故障排查手册 (Troubleshooting)](docs/TROUBLESHOOTING.md)
- [框架与系统兼容性说明](docs/COMPATIBILITY.md)
- [非专有二进制分发声明](NO_PROPRIETARY_BINARIES.md)
- [免责声明](DISCLAIMER.md)
- [安全政策](SECURITY.md)

---

## 许可证 (License)

本项目采用 [GNU General Public License v3.0 (GPL-3.0)](LICENSE) 开源许可证。
