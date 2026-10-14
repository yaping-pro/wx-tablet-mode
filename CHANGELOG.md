# 变更日志 (Changelog)

本项目所有显著变更均记录于此文档。
本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范，格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [Unreleased]

### Added
- **新增 Telegram 交流群作为二维码过期后的长期备用联系通道**：在 README 中文/英文「讨论与交流」区块与 GitHub Issue 模板中补充 [t.me/WeChatExporter](https://t.me/WeChatExporter) 入口；微信交流群二维码（`assets/wechat-group-qr.png`，有效期至 2026-10-20）与 GitHub Discussions 双轨方式保持不变。

### Changed
- **构建工具链现代化升级（AGP 9.4.1 + Gradle 9.8.1 + 内置 Kotlin）**：升级 Android Gradle Plugin 至 `9.4.1`，Gradle Wrapper 至 `9.8.1`；移除独立的 `org.jetbrains.kotlin.android` 插件，改用 AGP 9 内置 Kotlin 支持，配置由 `android.kotlinOptions` 迁移为顶层 `kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }`；清理并收敛所有 Dependabot 依赖 PR。

### Fixed
- **免密 CI 构建签名与发布资产命名规范化**：CI 签名流程引入瞬时 debug 密钥（transient debug keystore），允许在未注入官方 release secrets 场景下（如 Fork / PR）平滑完成构建，并通过 `KEYSTORE_SOURCE=official|transient` 环境变量门禁证书指纹断言；对非 tag 引用的发布产物文件名执行字符过滤清洗，避免特殊分支引用破坏打包复制。
---
## [v1.0.6] - 2026-10-14
### Added
- **恢复微信交流群二维码**：恢复微信交流群二维码（`assets/wechat-group-qr.png`，群名称“微信个人助理交流”，有效期至 2026-10-20），并在 README / GitHub Issue 配置中补充有效期与 Discussions 双轨支持说明。
- **开机后置验证协议 (`scripts/verify_post_boot.sh`)**：根据重启持久化分析（§7 Precaution 3），提供自动化设备验证工具，一次性校验 Vector 守护进程作用域包含 `com.wx.pad`（含用户 999/0）以及微信主进程 `/proc/<pid>/maps` 模块映射与 logcat 签名。

### Documented
- **Android 12 FBE 锁屏解锁约束与开机后置验证**：在 `README.md`（FAQ Q6 中英双语）与 `AGENT.md`（Step G）中明确：冷启动后受 Android 12 FBE 文件加密约束，分身空间（u999）需在用户首次解锁屏幕后方可访问与自启微信；记录了开机后置校验流程。

---


## [v1.0.5] - 2026-10-14
### Fixed
- **Vector 克隆空间注入缓存失效 (Clone-Space Cache Quirk)**：当模块 `com.wx.pad` 通过 `pm install-existing --user 999 com.wx.pad` 安装进分身空间（User 999）后，Vector 守护进程内存态 `DaemonState.validUserIds` 仍停留在 `{0}`，会**静默跳过 u999 注入**，直到通过 CLI 执行 `modules disable` → `modules enable` → `scope set` 强制重建缓存。已在 `AGENT.md` 与 `docs` 中补充修复步骤（见下方 Documented）。

### Hardened
- **认证态重置/回滚测试可注入性 (`MM_DATA_ROOT`)**：`scripts/reset_wechat_auth.sh` 与 `scripts/rollback_wechat_auth.sh` 新增可选环境变量 `MM_DATA_ROOT`，默认值仍为 `/data/user/<UID>`，**不改变任何设备语义**；仅用于指向沙箱/测试目录以便离线校验脚本逻辑。子目录完整相对路径保留（自 v1.0.4 起）保持不变。

### Documented
- **运行时软开关属性矩阵**：于 `docs/EXTERNAL_HOOK_SPEC.md` 与 README FAQ 详述 `persist.wx.pad.loginhook` / `persist.wx.pad.disguise` 在 `0` / `1` / 未设置 三种取值下的行为对照（见 README FAQ Q8）。
- **外部闭源 Hook 毕业迁移 SOP**：新增从 `com.roro.tablethook` 平滑毕业至内置 `PadLoginHook` 的标准操作（并行启用 → 验证 logcat 签名 → 停用外部 Hook → 回滚预案），见 README FAQ Q9 与 `docs/EXTERNAL_HOOK_SPEC.md`。

### Verified
- **内置 Hook 与 roro 实机对等**：`com.wx.pad` v1.0.4 的 `PadLoginHook` 已**实机验证可用**（`com.wx.pad: 微信平板登录模式已启用`，DexKit 候选 平板 2/1、资格 1/1，与 `com.roro.tablethook` 完全一致），内置模块可完整替代外部闭源 Hook。

---

## [v1.0.4] - 2026-10-13
### Fixed
- **合规去引流化 (L-001)**：彻底移除微信交流群临时二维码（`assets/wechat-group-qr.png`）及其相关引用，技术支持与交流统一迁移至 GitHub Discussions。
- **法律术语合规修正 (L-002)**：删除“Clean-Room/净室”用语，如实表述为“第一方 GPL-3.0 实现，匹配器设计参考/衍生自 Houvven/I-Am-Pad (GPL-3.0) 并保留完整署名”。
- **发布签名指纹真值断言 (R-001)**：CI 流水线中引入 `apksigner verify --print-certs` SHA-256 指纹强校验门禁（白名单 `76:AD:A6:...`）与 4 字节 `zipalign -c -v 4` 门禁，并在 `SECURITY.md` 中公示官方签名指纹。
- **构建产物真实命名 (R-002)**：将 Release APK 从误导性的 `-universal.apk` 更正为符合架构实际的 `wx-tablet-mode-${TAG}-arm.apk` (arm64-v8a + armeabi-v7a)，同步更新文档与引导指南。
- **版本漂移与单一真值源 (R-003)**：消除文档中硬编码的旧版 `v1.0.2` 安装命令，统一建立泛化最新 Release 资产引用规范。
- **认证态重置与回滚脚本重构 (O-004)**：重写 `scripts/reset_wechat_auth.sh` 与 `rollback_wechat_auth.sh`，保留完整的子目录相对路径消除同名覆盖隐患，精准对齐 `/MicroMsg/autoauth.cfg` 等真实设备路径，新增 `--dry-run` 预览模式与幂等空跑保护。

---
## [v1.0.3] - 2026-10-13
### Fixed
- 修复 CI 签名配置：启用 v1 (JAR) 与 v2 (APK Signature Scheme v2) 签名并添加自动化发布校验。

## [v1.0.2] - 2026-10-13
### Added
- **完全自包含第一方 Pad 登录资格 Hook (`PadLoginHook`)**：基于 LuckyPray/DexKit 动态扫描匹配，在单一 APK 内同时集成外观伪装 (`PadDisguise`) 与第一方平板登录扫码资格，彻底消除对外部闭源第三方 APK 的依赖。
- 自动化构建产物规范化：CI 自动打包命名为 `wx-tablet-mode-v1.0.2-universal.apk` 并附着于 Release。

### Changed
- 统一重命名各处文档对兄弟仓库的引用为 `wx-pad-exporter`。
- 完善免责声明与安全政策中关于自包含 Hook 实现的合规边界说明。

---

## [v1.0.1] - 2026-10-13
### Added
- 微信平板模式外观伪装 Xposed/LSPosed 模块发布 (`com.wx.pad`)。
- CI 自动化构建流水线与 Release 资产分发机制。

### Fixed
- 修复部分折叠屏设备 DPI 与平板特征参数适配逻辑。

---

## [v1.0.0] - 2026-10-13
### Added
- 项目初次开源发布：包含基础平板外观伪装 Xposed 模块框架与诊断排错脚本。
