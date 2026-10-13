# 变更日志 (Changelog)

本项目所有显著变更均记录于此文档。
本项目遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范，格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [Unreleased]
### Added
- 基础开源协作治理规范：Issue Templates (Bug Report / Feature Request / Config)、PR Template、CODEOWNERS、Dependabot 自动依赖更新及分支保护策略。

---

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
