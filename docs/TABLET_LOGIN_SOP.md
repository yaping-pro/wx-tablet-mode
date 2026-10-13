# 微信平板副设备登录标准作业程序 (Tablet Login SOP)

> **适用场景**：在 Android 手机（如 Redmi 10X / `atom`）分身空间（User 999）中，通过 TabletHook 将微信伪装为平板设备并拉起 `LoginAsExDeviceUI` 二维码，由主力机微信扫码授权登录，实现同账号/双设备共存。  
> **验证基线**：微信官方正式版 `8.0.78` (`0x28004e32`) + 干净认证状态（`autoauth.cfg=0`、无 `auth_ishold`）。

---

## ⚡ 30 秒极简速查表

### 前置条件

- **运行环境**：Android 12+，Magisk 27.0+ (Zygisk 启用)，Vector API 102 Xposed 框架正常激活。
- **模块加载**：`com.roro.tablethook` 与 `com.wx.pad.sniffer` 已在 user 999 启用并生效。
- **权限与环境**：设备具备 Root 权限，网络环境直连本地网关（局域网 IP 保持一致）。

### 5 步标准操作与验收判据

| 步骤 | 操作内容 | 关键命令 / 动作 | 核心验收判据 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **确认客户端构建身份** | ① `md5sum $(pm path --user 999 com.tencent.mm | sed s/package://)` 比对官方底包 md5 `846b411199ae49d335d31b3a17036440`；② 读 `tinker_ensurance_info.xml` 的底包版本；③ 查 `tinker/` 下有无 `patch-*`；④ 读 `tinker_patch_share_config.xml` 的 `tinker_patch_version_key` | 底包 md5 匹配官方；`tinker_patch_version_key` 末字节为 `32`（非 `38`）；`tinker/` 无 `patch-*` |
| **Step 2** | **换装官方版本** | 下载腾讯官方 CDN 安装包，执行 `pm install -r -d` 覆盖安装 | 返回 `Success`，DexKit 候选识别数量一致（`2,1` / `1,1`） |
| **Step 3** | **重置认证状态** | 备份并移走 `autoauth.cfg` 与 `auth_hold_prefs.xml` | `autoauth.cfg` 归 0 字节，`auth_hold_prefs.xml` 不存在 |
| **Step 4** | **重启分身微信** | `am force-stop` 并重启 `com.tencent.mm/.ui.LauncherUI` | Logcat 打印 `微信平板登录模式已启用`，PID 正常分配 |
| **Step 5** | **扫码授权验收** | 拉起 `LoginAsExDeviceUI`，主力机扫码并点击确认 | `autoauth.cfg` 变为 1114 字节，进入 `LauncherUI`，daemon 捕获消息 |

---

## 📊 成功条件三要素与组合决策矩阵

微信副设备平板登录鉴权的核心在于**双端握手与服务端风控校验**。服务端会在主力机点击「确认登录」的瞬间核验副设备的构建版本与会话状态。

### 成功条件三要素

- **官方构建包（底包 APK 版本末字节非 `0x38`）**：指由 **APK 字节 / `tinker_ensurance_info.xml` 判定的底包身份**（非运行时上报的 `last_reportdevice_clientversion` 缓存值）。服务端对带有 Beta/内测标记（底包如 `0x28004e38`）的副设备登录进行严格白名单过滤，非受邀账号必被拦截。
- **纯净初始认证态（Clean Auth State）**：本地 `autoauth.cfg` 必须为 0 字节初始态，且严禁残留 `auth_ishold=true`（挂起标记）。陈旧 Token 会触发凭证冲突重放。
- **有效内存伪装（TabletHook 激活）**：DexKit 成功命中 `isTabletDevice` 与 `checkloginaspad`，保证副设备登录入口 `LoginAsExDeviceUI` 正常呈现。

### 状态组合测试矩阵

| 微信构建版本 | 本地认证态 | 实测结果 | 根因与机理分析 |
| :--- | :--- | :--- | :--- |
| **Beta 版 (`0x28004e38`)** | 干净态 (`autoauth=0B`, 无 hold) | ⚠️ **不稳定 / 偶发失败** | 01:59 首次绑定侥幸通过；12:57 再次确认时被服务端以 Beta 资格直接拦截 |
| **Beta 版 (`0x28004e38`)** | 脏状态 (`autoauth=1090B`, `auth_ishold=true`) | ❌ **100% 失败** | 双重违规：服务端命中 Beta 拦截规则 + 客户端携带陈旧挂起凭证重放 |
| **官方版 (`0x28004e32`)** | 脏状态 (`autoauth=1090B`, `auth_ishold=true`) | ❌ **高概率失败** | 客户端处于挂起态，扫码无法完成新会话建立，易引发状态机死锁 |
| **官方版 (`0x28004e32`)** | 干净态 (`autoauth=0B`, 无 hold) | ✅ **100% 成功 (标准生产态)** | **13:01 实测秒级进入 LauncherUI，写入 1114 字节 auth，同步 74 条消息** |
> 注：表中的 `0x28004e38` / `0x28004e32` 是**运行时上报值**；判定底包身份请看 §Tinker 陷阱的「判别方法」（APK md5 + `tinker_ensurance_info.xml` + `tinker_patch_version_key`），不要用 `last_reportdevice_clientversion` 缓存字段当身份依据。

---

## 🛠 详细操作流程 (Numbered Steps)

> **说明**：以下操作中，设备序列号统一记为 `xs9ponj…(redacted)`，局域网 IP 记为 `192.168.x.x`。

### 步骤 1：确认当前微信构建与渠道

> ⚠️ **判定底包身份，绝不用 `last_reportdevice_clientversion`**（运行时会变的缓存，被 Tinker 热更改写，且每用户不同）。必须用以下 APK 字节 + Tinker 记录链。详见 §Tinker 陷阱的「判别方法」。

```bash
# 1. 取 u999 微信 APK 实际路径并对文件做 md5（最权威）
adb -s xs9ponj…(redacted) shell "su -c 'md5sum \$(pm path --user 999 com.tencent.mm | sed s/package://)'"

# 2. 读底包记录（底包身份，不受热更影响）
adb -s xs9ponj…(redacted) shell "su -c 'cat /data/user/999/com.tencent.mm/shared_prefs/tinker_ensurance_info.xml'"

# 3. 查是否下发了 Tinker 热更补丁
adb -s xs9ponj…(redacted) shell "su -c 'ls /data/user/999/com.tencent.mm/tinker/'"

# 4. 读热更版本（若有补丁，看它把版本抬到哪）
adb -s xs9ponj…(redacted) shell "su -c 'cat /data/user/999/com.tencent.mm/shared_prefs/tinker_patch_share_config.xml | grep tinker_patch_version_key'"
```

**判据**：APK md5 = `846b411199ae49d335d31b3a17036440`（官方底包 `0x28004e32`）；`tinker_patch_version_key` 末字节为 `32`（**非 `38` Beta**）；`tinker/` 下无 `patch-*`。

*注：若仍想**观测**运行时上报值（仅供参考，会变、不可据此判定身份），可 `cat com.tencent.mm_preferences.xml | grep last_reportdevice_clientversion`；例如 `671108664` = `0x28004e38` 末字节 `38` 即被抬到 Beta 通道——这正是 Tinker 陷阱的症状，而非底包身份。*

### 步骤 2：换装微信官方正式版 (0x28004e32)

若当前为 Beta 版本，必须替换为腾讯官方 CDN 发布的正式版 APK。

#### 官方安装包源信息

- **腾讯官方 CDN 直链**：`https://dldir1v6.qq.com/weixin/android/weixin8078android3180_0x28004e32_arm64.apk`
- **文件大小**：`280,614,450` 字节 (~268MB)
- **SHA-256**：`41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba`

#### 执行安装与回归检查

```bash
# 1. 下载并推送到设备临时目录
adb -s xs9ponj…(redacted) push weixin8078android3180_0x28004e32_arm64.apk /data/local/tmp/mm_official.apk

# 2. 执行原地覆盖更新 (-r 保留数据, -d 允许降级/同级覆盖)
adb -s xs9ponj…(redacted) shell "su -c 'pm install -r -d /data/local/tmp/mm_official.apk'"
```

**期望回显**：

```text
Success
```

#### 校验 TabletHook 与 DexKit 兼容性

换装完成后启动微信，验证 DexKit 特征搜索是否准确命中：

```bash
adb -s xs9ponj…(redacted) shell "su -c 'am force-stop --user 999 com.tencent.mm'"
adb -s xs9ponj…(redacted) shell "su -c 'am start --user 999 -n com.tencent.mm/.ui.LauncherUI'"
sleep 3
adb -s xs9ponj…(redacted) shell "logcat -d | grep -E 'TabletHook|VectorModuleManager'"
```

**期望输出**：

```text
D VectorModuleManager: Loaded module com.roro.tablethook successfully.
I TabletHook: com.roro.tablethook: DexKit 微信平板判定候选：关键词=2，签名=1
I TabletHook: com.roro.tablethook: DexKit 微信副设备登录资格候选：关键词=1，签名=1
I TabletHook: com.roro.tablethook: 微信平板登录模式已启用
```

---

### 步骤 3：重置 u999 微信认证状态（可逆安全操作）

清理本地残留的失效 Token 与挂起标记，使其恢复至初次安装后的干净白纸状态。**严禁删除 `EnMicroMsg.db` 聊天数据库**。

```bash
# 1. 建立时间戳备份目录
TS=$(date +%Y%m%d_%H%M%S)
adb -s xs9ponj…(redacted) shell "su -c '
mkdir -p /data/adb/wx_stream/backup_auth_${TS}
chmod 700 /data/adb/wx_stream/backup_auth_${TS}

# 2. 移走 autoauth.cfg 与 auth_hold_prefs.xml
if [ -f /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg ]; then
    mv /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg /data/adb/wx_stream/backup_auth_${TS}/autoauth.cfg.moved
fi
if [ -f /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml ]; then
    mv /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml /data/adb/wx_stream/backup_auth_${TS}/auth_hold_prefs.xml.moved
fi
'"
```

**验收检查**：

```bash
adb -s xs9ponj…(redacted) shell "su -c 'ls -la /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml'"
```

**期望回显**：两者均提示 `No such file or directory`。

---

### 步骤 4：重启分身微信并确认状态重置

```bash
# 1. 强制杀死并重启微信
adb -s xs9ponj…(redacted) shell "su -c 'am force-stop --user 999 com.tencent.mm'"
sleep 2
adb -s xs9ponj…(redacted) shell "su -c 'am start --user 999 -n com.tencent.mm/.ui.LauncherUI'"
sleep 3

# 2. 检查微信是否重新生成 0 字节的干净 autoauth.cfg
adb -s xs9ponj…(redacted) shell "su -c 'ls -l /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg'"
```

**期望回显**：

```text
-rw------- 1 <CLONE_UID> <CLONE_UID> 0 2026-10-03 12:52 /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg
```

---

### 步骤 5：拉起平板登录二维码并完成扫码验收

#### 1. 拉起二维码登录界面

```bash
adb -s xs9ponj…(redacted) shell "su -c 'am start --user 999 -n com.tencent.mm/.plugin.login_exdevice.ui.LoginAsExDeviceUI'"
```

#### 2. 获取二维码截图至 Mac 查看

```bash
adb -s xs9ponj…(redacted) shell "screencap -p /data/local/tmp/qr_login.png"
adb -s xs9ponj…(redacted) pull /data/local/tmp/qr_login.png /tmp/qr_login.png
open /tmp/qr_login.png
```

#### 3. 主力机扫码并在手机上点击「确认登录」

#### 4. 全链路验收指标核验

```bash
# 1. 检查焦点 Activity 是否自动切换至 LauncherUI
adb -s xs9ponj…(redacted) shell "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'"

# 2. 检查 autoauth.cfg 大小是否跳变至 >0 (通常为 1114 字节)
adb -s xs9ponj…(redacted) shell "su -c 'ls -l /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg'"

# 3. 检查 default_uin 是否成功持久化 (非 0)
adb -s xs9ponj…(redacted) shell "su -c 'cat /data/user/999/com.tencent.mm/shared_prefs/system_config_prefs.xml | grep uin'"

# 4. 检查微信主数据库 EnMicroMsg.db 是否正常扩增
adb -s xs9ponj…(redacted) shell "su -c 'ls -l /data/user/999/com.tencent.mm/MicroMsg/*/EnMicroMsg.db'"

# 5. 检查 wx-pad-sniffer 后台 daemon 状态与消息接收
curl -s http://127.0.0.1:8765/health
curl -s http://127.0.0.1:8765/api/wechat/export | jq '{message_count: .chats[0].messages | length, chat_name: .chats[0].name}'
```

**实测成功标准回显 (2026-10-03 13:01 真实记录)**：

```text
mCurrentFocus=Window{8f948b3 u999 com.tencent.mm/com.tencent.mm.ui.LauncherUI}
-rw------- 1 <CLONE_UID> <CLONE_UID> 1114 2026-10-03 13:01 /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg
<long name="default_uin64" value="546527069" />
<int name="default_uin" value="546527069" />
-rw------- 1 <CLONE_UID> <CLONE_UID> 6329344 2026-10-03 13:04 .../EnMicroMsg.db

{"status":"ok","uptime_seconds":30004,"uds_connected":true,"active_uds_connections":2,"total_messages":74,"total_received_stream":74,"memory_bytes":1585024,"version":"1.0.0-pad"}
```

---

## 🔍 排错与避坑指南 (Troubleshooting)

| 故障现象 (Symptom) | 诊断判据 (Criterion) | 根本原因 (Root Cause) | 处置手段 (Action) |
| :--- | :--- | :--- | :--- |
| 扫码确认后弹出 `The beta version is only for eligible users` | 焦点停留在 `LoginAsExDeviceUI`，`autoauth.cfg` 仍为 0 字节 | 微信包为 Beta 构建 (`0x38`) 或服务端识别到会话异常频控 | 执行步骤 2 换装官方版 `0x28004e32`，并执行步骤 3 重置认证态 |
| 启动微信后未弹出二维码，直接进入输入密码界面 | `mCurrentFocus` 为 `LoginPasswordUI` | `TabletHook` 未生效或未注入 user 999 空间 | 检查 Vector 模块列表中 `TabletHook` 是否勾选 user 999 范围 |
| 日志显示 `auth_ishold=true` | `auth_hold_prefs.xml` 包含 `<boolean name="auth_ishold" value="true" />` | 上次登录异常中断导致客户端会话进入挂起死锁状态 | 强制移走 `auth_hold_prefs.xml` 并重启微信进程 |
| DexKit 候选日志看起来缺失 | `logcat -d` 无 `DexKit 微信平板判定候选` 关键字 | logcat 缓冲区溢出被截断，或进程尚未完成 Dex 索引 | 微信冷启动后 `sleep 3` 再执行 `logcat -d \| grep TabletHook` |
| 怀疑 sing-box / 代理网络导致扫码被风控 | 微信网络连接报错或连接延迟 | 误判：实测 sing-box 对 `com.tencent.mm` 配置了 `direct` 出口 | 检查 sing-box 规则确保微信直连本地网关，避免节点漂移 |
| 试图通过 xlog 查看服务端拒绝明文 | 读取 `/data/user/999/com.tencent.mm/files/xlog/*.xlog` | Mars xlog 采用 ECC secp256k1 ECDH 加密，服务端私钥不公开 | 放弃离线解密 xlog，转为通过 Activity 栈、`autoauth.cfg` 与 UI 截图取证 |
| daemon 健康探针 `uds_connected:false, total_received_stream:0`，但 daemon 与微信均运行正常 | `grep -icE "sniffer" /proc/<u999微信PID>/maps` 返回 0（微信进程内存中未映射 sniffer 模块） | 模块（如 `com.wx.sniffer` / `com.roro.tablethook`）仅安装于 user 0，未 `pm install-existing --user 999`；Vector 框架按 user 查询包信息，对 user 999 查不到该包 → 静默跳过注入，Hook 永不接线（"看着通了，数据是死的"） | `pm install-existing --user 999 com.wx.sniffer` 与 `pm install-existing --user 999 com.roro.tablethook`；重启微信后 `maps` 判据应 > 0 |
| 冷启动后 `dumpsys user` 显示 `RUNNING_LOCKED`，微信起不来，daemon `uds_connected:false` | `dumpsys window | grep isKeyguardShowing` → `isKeyguardShowing=true`；`dumpsys user` → `...=RUNNING_LOCKED`；`autoauth.cfg` 不存在 | 设备带 PIN 锁屏，冷启动处于 Direct Boot 阶段；user 999 的 CE（凭据加密）存储在首次解锁屏幕前不可访问 → 微信无法启动。`wx_autostart.sh` 的 Watchdog（`while true; sleep 30`）只能在用户解锁后才成功拉起 | **运维前置：每次重启后需人工解锁屏幕一次（之后可再锁屏），线路才恢复**；严禁任何自动化尝试猜测/枚举/清除锁屏凭据。**若该设备为专用采集终端，可移除锁屏凭据以获得全自动（实测重启后 ~67s 全链路自动恢复，0 人工介入；需权衡安全，见 `docs/phone-endpoint-spec.md` §7.4 安全边界）** |
| 重启后 daemon 与微信都没起来,自启脚本日志里只有一行不起眼的 `Failed transaction (2147483646)`,但脚本"看起来跑完了" | `grep -i "Failed transaction" /data/adb/wx_stream/*.log`;或 `dumpsys package` 看 user 999 是否真装了模块 | `am`/`pm` 输出被重定向到 root-only 目录(`/data/adb/`,0700),`cmd` 把 fd 经 Binder 交给 `system_server`(uid 1000),DAC 拒绝 → **整个 Binder 事务失败,命令静默失效** | 所有 `am`/`pm`/`settings`/`svc`/`dumpsys` 调用必须 `>/dev/null 2>&1` 或重定向到 `/data/local/tmp/`(0771);用纯 shell 的 `echo >>` 在调用**前后**记录结果与 rc |
| 微信每隔约 60 秒自动退出/闪退，但 daemon 与其它服务正常 | `logcat -d -b all \| grep "Force stopping com.tencent.mm"` 有周期性记录，且 `from process:<pid>` 指向自启脚本的健康检查子进程 | Watchdog 把"`uds_connected:false`"错误归因为"微信故障"→ 无退避、无上限地 `am force-stop` 微信；叠加 `.bak` 被 Magisk 当作脚本执行导致**双 watchdog 实例**，以及冷启动期（需 20–40s 建 UDS）被过早判故障 | **守护原则：对微信只"拉起"、绝不"杀死"**；修复 `force-stop` 逻辑 → 改为只记限流日志；加单例锁；加 90s 冷启动冷却；`.bak` 备份**绝不可放在 `service.d/`**（Magisk 会执行目录下所有 `.sh`） |
| 之前能登录,突然被拒 `The beta version is only for eligible users`,但 APK 是官方包、认证态也干净 | `ls /data/user/999/com.tencent.mm/tinker/` 有 `patch-*`;`tinker_patch_share_config.xml` 的 `tinker_patch_version_key` 末字节为 `38` | 微信自动下发 Tinker 热更补丁,把运行时 clientversion 抬到 beta 通道 | 隔离 `tinker/patch-*` + `patch_meta.info` 到 `/data/adb/wx_stream/tinker_quarantine/`,回正 prefs 为底包版本,重启微信 |

## 🧨 陷阱: Tinker 热更补丁导致"登录突然失效" (Tinker Hotfix Beta Regression)

> **重要度**：这是"登录突然失效"的**头号原因**，且**极难排查** —— 症状看起来像账号问题（beta 资格被拒），但**根因是客户端运行时被热更改写**。以下结论来自 2026-10-03 真机实测。

### 🩺 症状

平板副设备原本已正常登录/可登录，某次扫码或点击「确认登录」时**突然**被服务端拒绝，弹窗：

```text
The beta version is only for eligible users. Download the latest official version.
```

底层包本身是官方正式版（`0x28004e32`），但运行时上报的 `clientversion` 变成了 beta 通道 `0x28004e38`，于是服务端按 Beta 资格拦截。

| 项 | 值 |
| :--- | :--- |
| **底包 APK** | `0x28004e32`（官方，CHANNEL=00000，md5 `846b411199ae49d335d31b3a17036440`） |
| **补丁路径** | `/data/user/<uid>/com.tencent.mm/tinker/patch-<hash>/` |
| **补丁版本** | `0x28004e38`（末字节 **38** = beta 通道） |
| **版本记录** | `tinker_patch_share_config.xml` 的 `tinker_patch_version_key`；底包记录在 `tinker_ensurance_info.xml` |
| **实测案例** | 2026-10-03 13:41:21 下发，此后每次登录均被拒；移除补丁后 `clientversion` 回 `0x4e32`，弹窗消失 |
| **user 0 对比** | user 0 无该补丁 → 说明是**每用户独立**下发 |

### 🤔 为什么难排查（三个会误判的方向）

1. **误判①：账号无 beta 资格。** 弹窗字面意思是"beta 仅限受邀用户"，第一直觉是账号不在白名单。→ 但本机是**主力日常账号**、从未申请过 beta，资格问题无法解释"之前能登、现在突然不能"。
2. **误判②：装了 beta 包。** 排查通常会先去查 APK 是不是内测版。→ 但 `pm path` 指向的 APK 是**官方底包** `0x28004e32`，APK 字节本身并无 beta 标记，靠"换装官方包"无效（因为本来就是官方包）。
3. **误判③：陈旧认证态。** 按常规 SOP 怀疑 `autoauth.cfg` / `auth_ishold`。→ 但认证态是干净的（`autoauth.cfg=0B`、无 hold），重置认证态也**不能**恢复登录。

三者都排除后仍失败，才会陷入死胡同——**真正的根因是微信在运行时自动下发了 Tinker 热更补丁**，把上报版本从官方底包抬到 beta 通道，而 APK 文件本身从未变过。

### 🔍 判别方法（正确判断链）

> ⚠️ **铁律：不要用 `last_reportdevice_clientversion` 判断构建身份。** 它是**运行时会变的缓存**（微信"最后一次上报"的值），会被热更改写，且**每个用户不同**（实测 u999=`0x4e38`、u0=`0x4a52`）。把它当"APK 身份"会直接误判。

建立构建身份必须用以下 4 步，按可信度从高到低：

1. **看 APK 字节（最权威）**：
   ```bash
   # 取微信 APK 实际路径并对文件做 md5
   md5sum $(pm path com.tencent.mm | sed s/package://)
   # 分身空间也要单独看
   pm path --user 999 com.tencent.mm
   ```
   与已知官方包比对：官方底包 md5 = `846b411199ae49d335d31b3a17036440`（版本 `0x28004e32`）。
2. **看底包记录（底包身份，不受热更影响）**：读 `tinker_ensurance_info.xml` 里记录的版本，这才是底包真实身份。
3. **看是否有热更**：
   ```bash
   ls /data/user/<uid>/com.tencent.mm/tinker/
   ```
   看是否存在 `patch-*` 目录（有即代表微信下发了热补丁）。
4. **看热更版本**：
   ```bash
   cat /data/user/<uid>/com.tencent.mm/shared_prefs/tinker_patch_share_config.xml | grep tinker_patch_version_key
   ```
   `tinker_patch_version_key` 末字节为 `38` 即 beta 通道补丁（正常应为底包 `32`）。

### 🛠 修复（隔离，不要删）

把热补丁**移出**（移到隔离区，**不要删除**，便于回溯）并回正 prefs，再重启微信：

```bash
TS=$(date +%Y%m%d_%H%M%S)
QZ="/data/adb/wx_stream/tinker_quarantine/${TS}_patches"
mkdir -p "$QZ"

# 1. 隔离 patch-* 目录与 patch_meta.info（只移动，不删除）
mv /data/user/999/com.tencent.mm/tinker/patch-* "$QZ/" 2>/dev/null
mv /data/user/999/com.tencent.mm/tinker/patch_meta.info "$QZ/" 2>/dev/null

# 2. 回正 prefs 为底包版本
TINKER_PREF="/data/user/999/com.tencent.mm/shared_prefs/tinker_patch_share_config.xml"
sed -i 's/0x28004e38/0x28004e32/g' "$TINKER_PREF"
chown <CLONE_UID>:<CLONE_UID> "$TINKER_PREF"
chmod 660 "$TINKER_PREF"

# 3. 重启微信
am force-stop --user 999 com.tencent.mm
sleep 2
am start --user 999 -n com.tencent.mm/.ui.LauncherUI
```

> 要点：**只移动不删除**（保留 `tinker_quarantine/` 便于事后取证）；`patch_meta.info` 也要一并移走，否则微信会按元数据重新加载补丁。

### 🛡 持久化防御（watchdog 自动隔离）

`deploy/wx_watchdog.sh` 的 **H 段**已内置持久化检肃：每 30s 扫描 `tinker/` 目录，一旦发现 `patch-*` 或 `patch_meta.info` 即**隔离到 `/data/adb/wx_stream/tinker_quarantine/`**（只移动、绝不杀微信），并 `sed` 回正 `tinker_patch_version_key` 为底包 `0x28004e32`。**守护原则：对微信只"拉起"、绝不"杀死"**——热补丁回潮的处置同样只 quarantine，不 force-stop。

### 📈 实测数据（2026-10-03）

- **13:41:21** 微信自动下发 Tinker 热补丁（`tinker_patch_version_key` 由 `0x4e32` → `0x4e38`）。
- 此后**每次**扫码/确认登录均被服务端以 `The beta version is only for eligible users` 拒绝。
- 移除补丁（`patch-*` + `patch_meta.info` 隔离）、回正 prefs 后，`clientversion` 回到 `0x4e32`，弹窗消失，登录恢复正常。
- 对照：user 0 无该补丁，证明是**每用户独立**下发（与 user 999 的"之前能登、突然不能"形成因果闭环）。
### 🔋 全自动验证（无锁屏凭据部署）

若设备为专用采集终端且已移除锁屏凭据，重启后**无需任何人工介入**，整条链路会自动恢复。实测证据（2026-10-03，全程零人工）：

- `adb reboot` 后约 **53s** `sys.boot_completed=1`；
- 约 **65s** `wx_daemon` 就绪 + user 999 已 `RUNNING_UNLOCKED` + LauncherUI 自动拉起 + watchdog 启动；
- 约 **67s** 微信 PID 拉起且 `uds_connected:true`（boot 后仅 **14s**）。
- 零 force-stop、`autoauth.cfg`=1114B 完好、模块注入 `maps`=3、3 分钟 PID 恒定。

> 该能力的代价：设备不再有锁屏保护（物理失窃可直接访问微信会话与 `/data/adb/wx_stream/vault.db`）。仅适用于专用采集终端 + 物理受控环境；安全权衡详见 `docs/phone-endpoint-spec.md` §7.4。若设备恢复锁屏凭据，则回到"每次重启后需人工解锁一次"。

## ⚠️ Magisk service.d 的陷阱 (Pitfalls)

`/data/adb/service.d/` 是 Magisk 在开机早期自动执行的脚本目录。这里的坑一旦踩中，表现往往极其隐蔽（进程周期性被杀、命令静默失效、双实例互踩），且 `logcat` 里只有不起眼的记录。本轮 v2 升级正是为修复其中两条真实事故。

- **`service.d/` 下所有 `.sh` 都会被执行 —— 备份文件必须放在别处。** Magisk 不会区分"主脚本"还是"备份"，目录里每一个 `*.sh` 都会被 `sh` 跑一遍。把 `wx_autostart.sh` 的 `.bak` 留在 `service.d/` 里会导致**两个 watchdog 同时启动**，互相抢 PID 文件、重复杀进程、双写日志。正确做法：备份放到 `/data/adb/wx_stream/backup_scripts/`（非 `service.d/` 子目录）或任意不在 Magisk 扫描路径下的位置。

- **`am` / `pm` 的输出绝不能重定向到 root-only 目录。** 当 `am`/`pm`/`settings`/`svc`/`dumpsys` 的 stdout/stderr 被重定向到 `/data/adb/`（0700，owner root）这类 root-only 目录时，`cmd` 会把文件 fd 经 Binder 交给 `system_server`（uid 1000），DAC 拒绝 → 报 `Failed transaction 2147483646`，**整条 Binder 事务失败，命令静默失效**（模块没装、微信没拉起，但脚本"看起来跑完了"）。所有 framework 调用一律 `>/dev/null 2>&1`，或只重定向到 `/data/local/tmp/`（0771，uid 1000 可写）；需要留存结果时用纯 shell 的 `echo >>` 在调用前后记录。

- **守护进程必须有单例锁 + 退避 + 上限，且绝不能通过杀死被守护对象来"修复"问题。** 守护脚本的崩溃模式是"越修越坏"：v1 错误地把 daemon 侧 `uds_connected:false`（sniffer 模块已在无限重连）当成"微信故障"，于是对微信无退避、无上限地 `am force-stop`，制造出每 ~60s 闪退一次的**自噬循环**；再加上冷启动期（微信需 20–40s 才建好 UDS）被过早判故障。守护原则只有一条：**对被守护进程只"拉起"、绝不"杀死"**；UDS 异常只记限流日志。同时 watchdog 自身必须靠 PID 文件 + `kill -0` 维持唯一实例，并在启动时收割旧实例，避免双 watchdog 互踩。
---
## 🔒 运维安全边界 (Operational Safety Boundary)

本项目在自持/运维过程中**严禁触碰设备锁屏凭据（自动化脚本不得猜测/枚举/清除）**，明确以下边界：

- 禁止任何自动化脚本尝试猜测/枚举/清除设备锁屏凭据（`locksettings verify/set/clear`）。
- 设备锁屏与凭据文件（`locksettings.db` / `gatekeeper` / `spblob`）不在本项目的可操作范围内。若设备恢复锁屏凭据，则回到"每次重启后需人工解锁一次"前置约束。
- 若自持流程需要设备处于解锁态且设备带锁屏，应停下来由人工解锁，不得自动化绕过。
- **例外（人工运维选择）**：本专用采集终端的"无锁屏凭据"状态是运维人员**人工在设备设置中主动移除**的（纯手动、非脚本），以获得 100% 无人值守。该选择仅适用于专用采集终端 + 物理受控环境，安全权衡见 `docs/phone-endpoint-spec.md` §7.4；严禁通过本项目的任何代码/脚本自动执行移除。

> 注：移除锁屏凭据后，设备不再有锁屏保护（物理失窃可直接访问微信会话与 vault.db）。若设备用于日常或非受控位置，应恢复锁屏凭据并接受"每次重启后需人工解锁一次"的运维成本。
## 💾 应急回滚与恢复脚本

### 1. 微信构建回滚脚本 (`rollback_to_beta.sh`)

用于在需要对比测试时，快速将微信回滚至原 Beta 安装包。

```bash
#!/bin/bash
set -euo pipefail

SERIAL="xs9ponj…(redacted)"
# (已清理) 原 BETA_APK 指向 /tmp/wx-official/backup/mm_beta_backup.apk (md5: ab09795d32bb14e1903a9e43084ebe1b)
# 该临时备份目录已于 2026-10-03 删除；如需回滚请重新获取 Beta 包并填入下方路径
BETA_APK=""

echo "=== Rolling back WeChat to Beta APK ==="
if [ ! -f "$BETA_APK" ]; then
    echo "Error: Backup beta APK not found at $BETA_APK"
    exit 1
fi

echo "Pushing beta APK to device..."
adb -s "$SERIAL" push "$BETA_APK" /data/local/tmp/mm_beta_rollback.apk

echo "Installing beta APK (pm install -r -d)..."
adb -s "$SERIAL" shell "su -c 'pm install -r -d /data/local/tmp/mm_beta_rollback.apk'"

echo "Restarting u999 WeChat..."
adb -s "$SERIAL" shell "su -c 'am force-stop --user 999 com.tencent.mm'"
sleep 2
adb -s "$SERIAL" shell "su -c 'am start --user 999 -n com.tencent.mm/.ui.LauncherUI'"
sleep 5

echo "Verifying package info..."
adb -s "$SERIAL" shell "dumpsys package com.tencent.mm | grep -E 'versionName|versionCode|lastUpdateTime'"
adb -s "$SERIAL" shell "pm path com.tencent.mm"

echo "Rollback completed successfully."
```

### 2. 认证状态还原脚本 (`restore_auth.sh`)

用于一键还原备份的历史认证凭据与 `shared_prefs` 配置文件。

```bash
#!/usr/bin/env bash
# 用法: bash restore_auth.sh <TS>
set -euo pipefail
TS="${1:?usage: restore_auth.sh <TS>}"
D="/data/adb/wx_stream/backup_auth_${TS}"
SERIAL="xs9ponj…(redacted)"

echo "=== Restoring WeChat u999 auth state from $D ==="

adb -s "$SERIAL" shell "su -c '
if [ -f $D/autoauth.cfg.moved ]; then
    mv $D/autoauth.cfg.moved /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg
fi
if [ -f $D/auth_hold_prefs.xml.moved ]; then
    mv $D/auth_hold_prefs.xml.moved /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml
fi
chown <CLONE_UID>:<CLONE_UID> /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg 2>/dev/null || true
chown <CLONE_UID>:<CLONE_UID> /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml 2>/dev/null || true
chmod 600 /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg 2>/dev/null || true
chmod 660 /data/user/999/com.tencent.mm/shared_prefs/auth_hold_prefs.xml 2>/dev/null || true
'"

adb -s "$SERIAL" shell "su -c 'am force-stop --user 999 com.tencent.mm'"
sleep 2
adb -s "$SERIAL" shell "su -c 'am start --user 999 -n com.tencent.mm/.ui.LauncherUI'"
echo "Restoration complete. WeChat u999 restarted."
```
