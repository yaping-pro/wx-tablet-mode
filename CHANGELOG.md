# 变更日志 (Changelog)

本项目所有显著变更均记录于此文档。
本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范，格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

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
