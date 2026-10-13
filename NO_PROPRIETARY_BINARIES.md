# No Proprietary Binaries Statement

本项目（`wx-tablet-mode`）**绝不包含、分发或托管任何腾讯专有二进制文件**（包括但不限于微信官方客户端 APK、Dex 补丁、SO 动态链接库或资源文件）。

This project (`wx-tablet-mode`) **DOES NOT include, distribute, or host any proprietary Tencent binaries** (including but not limited to official WeChat client APKs, Dex patches, native `.so` libraries, or raw resource files).

---

## 1. 独立获取官方安装包 (Obtaining the Official Package)

使用本 SOP 或相关脚本前，用户必须自行从腾讯官方渠道获取正规的微信 Android 客户端安装包：

- **官方发布渠道**: [腾讯微信官方网站 (weixin.qq.com)](https://weixin.qq.com/)
- **经过验证的官方基线版本**:
  - 版本号: `8.0.78`
  - 内部 ClientVersion: `0x28004e32` (`arm64-v8a`)
  - 官方直链文件名特征: `weixin8078android3180_0x28004e32_arm64.apk`
  - 官方文件大小: `280,614,450` 字节
  - 官方 APK 校验和 (SHA-256):
    ```text
    41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba
    ```
  - 官方 APK 提取 MD5:
    ```text
    846b411199ae49d335d31b3a17036440
    ```

请在安装前务必比对校验和，确保底包未经任何第三方二次打包或恶意篡改。

---

## 2. 外部依赖说明 (External Dependencies)

本项目中的 `PadDisguise` 模块仅负责屏幕断点与竖屏锁定辅助，**不具备**微信平板副设备登录资格判决能力。

平板登录资格所需之协议 Hook（如 `com.roro.tablethook` 或用户自研逆向实现）属于外部第三方独立组件。本项目**不分发**任何第三方闭源 Hook APK，请根据 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md) 自行甄别并配置外部依赖。
