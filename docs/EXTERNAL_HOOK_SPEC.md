# Hook Specification: Built-in & External Protocol Hooks (协议 Hook 规范)

## 1. 核心定位与版本演进 (Role & Architecture Evolution)

在早期版本（v1.0.0 ~ v1.0.1）中，`wx-tablet-mode` 仅提供 `PadDisguise`（屏幕断点 `sw600dp` 伪装与竖屏锁定），平板副设备登录资格依赖用户自备外部第三方 Hook（如社区未声明开源许可证的 `com.roro.tablethook`）。

**自 v1.0.2 起，本项目全面实现第一方、自包含（Self-Contained）的纯开源方案**：
- **单一 APK 同时具备伪装与登录资格**：模块源码内置全新 `PadLoginHook` 组件，基于 LuckyPray/DexKit 动态特征匹配与拦截，直接赋予微信副设备扫码登录资格。
- **100% 纯开源与洁癖合规**：绝不打包、不分发任何第三方未授权闭源 APK（如 `tablethook.apk`）或腾讯专有二进制。所有逻辑均为遵循 GPL-3.0 的第一方源码实现。
- **外部 Hook 转为可选（Optional）兼容模式**：如果用户仍偏好使用自己编译或第三方提供的外部 Hook，可通过系统属性软开关一键禁用内置 Hook。
- **毕业里程碑 (Graduation Milestone) — 实机对等验证已完成**：`com.wx.pad` v1.0.4 的 `PadLoginHook` 已**实机验证与 `com.roro.tablethook` 完全对等**——DexKit 候选命中数一致（平板环境判定 2/1、副设备登录资格 1/1），且启动微信主进程后 Logcat 均输出标准特征信号 `com.wx.pad: 微信平板登录模式已启用`。由此，外部闭源 Hook 已不再是资格赋予的必要项，正式降级为**完全可选的兼容项**。新用户只需安装本模块即可获得扫码登录资格；历史 `com.roro.tablethook` 用户可按 README FAQ Q9 的 SOP 零风险平滑迁移至内置 Hook。


---

## 2. 内置 Hook 技术实现与靶点剖析 (`PadLoginHook`)

`com.wx.pad.PadLoginHook` 借鉴了开源项目 `Houvven/I-Am-Pad`（GPL-3.0）的成熟靶点与架构设计，借助 `LuckyPray/DexKit`（LGPL-3.0）在微信运行时动态定位混淆方法，无硬编码类名，具备极佳的跨小版本兼容性：

### 2.1 靶点一：平板/折叠屏环境判定 (`inTabletEnv`)
- **匹配规则**：在 `com.tencent.mm` 进程中扫描包含常数字符串 `"inTabletEnv"` 的 `public static boolean` 方法。
- **备选规则**：若主规则未命中，回退扫描 `com.tencent.mm.ui` 包中包含折叠屏特征字串（`royole`、`ro.os_foldable_screen_support`）的静态布尔方法。
- **拦截行为**：通过 Xposed `beforeHookedMethod` 强制短路返回 `true`。

### 2.2 靶点二：副设备扫码资格预检协程 (`checkloginaspad`)
- **匹配规则**：扫描参数列表为 `(String, String, Continuation)`、返回值为 `Object`，且常量池包含接口路径 `"/cgi-bin/micromsg-bin/checkloginaspad"`（类标识 `MicroMsg.CgiCheckLoginAsPad`）的协程方法。
- **拦截行为**：通过 Xposed `beforeHookedMethod` 强制短路返回 `true`（放行副设备资格判定）。

### 2.3 执行时机与防竞争保护
Hook 在 `TinkerApplication.onBaseContextAttached` / `Application.onCreate` 时触发，确保微信 BaseDexClassLoader 与内存 Dex 全部挂载后执行 DexKit 扫描，并在匹配完成后立即释放 DexKit 原生句柄，保持进程内存整洁。

---

## 3. 生效日志特征 (Logcat Verification)

当内置 `PadLoginHook`（或外部兼容 Hook）成功注入并生效时，启动微信主进程可在 Logcat 捕获到标准特征信号：

```text
I TabletHook: com.wx.pad: DexKit 微信平板判定候选：关键词=2，签名=1
I TabletHook: com.wx.pad: DexKit 微信副设备登录资格候选：关键词=1，签名=1
I TabletHook: com.wx.pad: 微信平板登录模式已启用
```

验证命令：
```bash
adb logcat -d | grep -E "微信平板登录模式已启用|微信副设备登录资格候选|微信平板判定候选" | tail -20
```

---

## 4. 双轨共存与运行时开关 (Coexistence & Toggles)

本项目设计了极简的 Android 系统属性软开关（`setprop`），无需重新编译或卸载 APK 即可灵活调控：

| 系统属性 (Property) | 默认值 | 作用说明 | 切换命令 |
| :--- | :---: | :--- | :--- |
| `persist.wx.pad.loginhook` | `1` (启用) | 控制内置 `PadLoginHook` 登录资格拦截器。设为 `0` 则停用内置资格 Hook，便于回退至外部第三方 Hook（如 `com.roro.tablethook`）。 | `su -c 'setprop persist.wx.pad.loginhook 0'` |
| `persist.wx.pad.disguise` | `1` (启用) | 控制 `PadDisguise` 外观与断点伪装（Build 字段与 `sw600dp`）。设为 `0` 则停用外观伪装，由外部模块独占伪装。 | `su -c 'setprop persist.wx.pad.disguise 0'` |

修改属性后，通过 `am force-stop com.tencent.mm` 重启微信即可即时生效。

---

## 5. 外部第三方 Hook 的兼容与配置（可选备用路径）

若您出于历史兼容需求选择使用外部独立 Hook（如 `com.roro.tablethook`）：
1. 建议先关闭内置登录资格 Hook 避免重复拦截：
   ```bash
   su -c 'setprop persist.wx.pad.loginhook 0'
   ```
2. 安装外部 Hook APK 并确保在 Vector / LSPosed 管理器中将其勾选至 `com.tencent.mm` 作用域；
3. 在 Android 多用户 / 分身空间（如 User 999）下，务必向分身用户补装：
   ```bash
   pm install-existing --user <TARGET_USER> <EXTERNAL_HOOK_PKG>
   ```

---

## 6. 法律合规与诚实声明 (Legal Honesty)

- **第一方干净实现**：本仓库分发的 APK 及其所有源码均系纯开源代码与标准开源库（GPL-3.0 / LGPL-3.0），**不包含任何闭源反编译代码或未授权第三方二进制**。
- **协议 Hook 风险与责任**：在内存中拦截并修改专有商业软件（微信）的设备校验逻辑属于逆向工程研究范畴，仅供用户在个人所有的设备与账号上进行合法学习与测试。用户须自行承担违反《腾讯微信软件许可及服务协议》可能导致的账号受限风险。
