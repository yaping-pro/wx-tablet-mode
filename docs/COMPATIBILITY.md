# 框架与设备兼容性矩阵 (Compatibility Guide)

## 1. Xposed 框架兼容性 (Vector API-102 vs LSPosed API-100)

在 Android 平板模式多端多登实践中，底层 Xposed 注入框架的选型至关重要：

| 框架 | API 版本 | 构造机制 | 兼容性评估 | 建议 |
| :--- | :--- | :--- | :--- | :--- |
| **Vector (v2.2+)** | **API-102** | 支持现代无参构造 `XposedModule()` | **推荐基线** | 完美兼容现代 DexKit 与 TabletHook 模块 |
| **LSPosed (1.9.2 及更早)** | **API-100** | 依赖反射带参构造 | ⚠️ **存在断裂** | 外部模块可能因缺少构造方法抛出 `NoSuchMethodException` |
| **KernelSU / APatch** | 依模块版本 | 取决于加载的 Zygisk 插件 | **良好** | 需配合 ZygiskNext + Vector 使用 |

> **关键经验**：若设备上同时存在 `zygisk_vector` 与 `zygisk_lsposed` 模块，两者的 Zygote 注入钩子会发生激烈竞争，极易导致 Zygote 循环崩溃。请确保**只保留启用其中一个**。

---

## 2. 微信客户端版本兼容性

| 微信版本 | 架构 | ClientVersion | MD5 | 兼容状态 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **8.0.78** | `arm64-v8a` | `0x28004e32` | `846b411199ae49d335d31b3a17036440` | **黄金基线 (Verified)** | 官方正式版，确定性通过多端扫码认证 |
| **8.0.78 Beta** | `arm64-v8a` | `0x28004e38` | - | ❌ **阻断** | 服务端直接下发资格限制弹窗 |
| `>= 8.0.79` | `arm64-v8a` | 动态 | - | ⚠️ **需验证** | 需跟进外部协议 Hook 对新版本的靶点适配 |

---

## 3. 设备与系统环境

- **测试验证设备**:
  - Redmi 10X 5G (`atom` / `M2004J7AC`), Android 12, MIUI 13
  - 环境：Magisk 27.0 + Zygisk + Vector v2.2 (API-102)
- **多用户 / 应用分身兼容性**:
  - 原生支持 User 0（物理平板单系统）
  - 原生支持 MIUI 双开分身（User 999）及 Work Profile，只需在对应用户空间下补装模块（`pm install-existing --user <UID> <PACKAGE>`）。
