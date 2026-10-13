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

## 2. 纯开源自包含实现与第三方专有二进制排斥声明 (Zero Third-Party Closed-Source Binaries)

本项目自 v1.0.2 起内置了第一方、遵循 GPL-3.0 许可证的 `PadLoginHook` 与 `PadDisguise`，所有模块逻辑均为第一方公开源码构建。

本项目**严禁且绝不分发、不托管任何未授权或闭源的第三方 APK**（包括社区流传的未声明开源许可证的 `com.roro.tablethook` / `tablethook.apk`）。用户仅需编译或下载由本仓库构建的单一开源 APK。如用户偏好使用外部 Hook，亦可通过系统属性软开关自由切换，但须自行甄别并合法获取其外部依赖。
