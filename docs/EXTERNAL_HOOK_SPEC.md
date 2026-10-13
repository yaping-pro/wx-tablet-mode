# External Protocol Hook Specification (外部协议 Hook 依赖规范)

## 1. 核心定位与职责契约 (Role & Boundary)

本项目（`wx-tablet-mode`）明确界定自身技术边界：

- **自研开源模块 `PadDisguise` (`com.wx.pad`)**:
  仅负责 Android 系统属性（`Build.MODEL`、`Build.DEVICE` 等）伪装、屏幕断点伪装（`smallestScreenWidthDp >= 600`、`SCREENLAYOUT_SIZE_XLARGE`）以及竖屏强制锁定，解决手机端界面分栏与排版问题。
- **登录资格授予 (Tablet Secondary Device Qualification)**:
  微信服务端判定当前客户端是否具备副设备扫码登录资格（返回扫码授权界面而非强制手机号密码踢出主力机），依赖**外部协议 Hook 模块**。

本项目**绝不分发、不内置、亦不修改**任何外部协议 Hook 二进制文件。

---

## 2. 外部依赖模块特征与自检 (Dependency Characteristics & Verification)

经过广泛技术验证与测试，以下为典型的外部协议 Hook 运行特征（以社区流传的 `com.roro.tablethook` 为参考基线）：

### 2.1 包名与组件标识
- **Package Name**: `com.roro.tablethook`（或用户自研具备等价能力的 Xposed 模块）
- **框架支持**: 需要基于 **API-102 (无参构造 `XposedModule()`)** 的现代 Xposed 运行时，如 **Vector v2.2+**。若在早期 LSPosed (API-100) 环境中运行，会因反射带参构造失败抛出 `NoSuchMethodException`。

### 2.2 核心行为特征与 Logcat 识别
当外部协议 Hook 正常注入并生效时，启动 WeChat（`com.tencent.mm`）进程可在 Logcat 中观察到如下特征日志：

```text
DexKit 微信平板判定候选：关键词=2，签名=1
微信副设备登录资格候选：关键词=1，签名=1
微信平板登录模式已启用
```

若 Logcat 中未出现上述日志，表明外部 Hook 尚未正确加载或未命中当前微信版本的目标方法。

### 2.3 内存 maps 验证
可通过 root shell 检查 WeChat 进程的内存映射，确认 Hook 模块及 native 库是否加载：

```bash
su -c 'grep -E "tablethook|libdexkit" /proc/$(pidof com.tencent.mm)/maps'
```

---

## 3. 多模块共存与开关配置 (Coexistence & Collision Prevention)

当同时安装外部协议 Hook 模块与本项目的 `PadDisguise` 时，两者可能在 `Build.MODEL` 或 `Configuration` 的 Hook 点发生竞争（Last-writer-wins）。

### 3.1 运行时开关机制
`PadDisguise` 提供了系统属性软开关：
- **默认状态**: 开启（`persist.wx.pad.disguise` 未设置或为 `1`）。
- **关闭外观伪装 (独占模式)**:
  若外部 Hook 自身已完整覆写了设备型号与屏幕断点，建议关闭 `PadDisguise` 的伪装，使外部 Hook 独占生效：
  ```bash
  su -c 'setprop persist.wx.pad.disguise 0'
  ```
  设置后强制停止并重启微信即可生效，无需重新编译或卸载 APK。

---

## 4. 获取与部署提示 (User Instructions)

1. 用户须自行通过合法开源社区、自主逆向研发或可信第三方获取适配目标微信版本的协议 Hook 模块。
2. 安装外部 Hook 模块后，在 Android 多用户 / 双开环境下（如 User 999），务必执行分身补装：
   ```bash
   pm install-existing --user <TARGET_USER> <HOOK_PACKAGE_NAME>
   ```
3. 在 Vector / Xposed 框架管理界面中，将目标用户下的 `com.tencent.mm` 勾选至模块作用域 (Scope)。
