# 微信 user 999 平板登录 — 成功取证汇总（SUCCESS_SUMMARY）

**设备**: `xs9ponj…(redacted)` (Redmi atom / M2004J7AC, Android 12 MIUI 13)
**取证时间**: 2026-10-03 ~02:01（本地）
**结论**: ✅ **user 999 微信平板登录已成功落地**

> 本文件全部内容摘录自会话既有证据文件（`restart_u999.md`、`verify_login_success.md`、`enable_lsposed.md`、`reboot_zygisk_recovery.md`、`api_incompat.md`、`module_verify2.md`），未做任何编造。

---

## 一、技术栈

| 组件 | 版本 / 标识 |
| :--- | :--- |
| Xposed 框架 | **Vector v2.2**（versionCode 3080，**API 102**） |
| 平板 Hook 模块 | **`com.roro.tablethook`**（TabletHook） |
| 微信 | **8.0.78**（`com.tencent.mm`）+ user **999** |
| 设备 | Redmi atom `xs9ponj…(redacted)`，Magisk 27.0 + Zygisk |
| 框架状态 | `zygisk_vector` ENABLED / `zygisk_lsposed` DISABLED（避免双 Zygisk 冲突） |

---

## 二、关键铁证

### 铁证 1 — TabletHook 注入硬证据：`/proc/18591/maps` 含 `libdexkit.so`
（来源：`restart_u999.md` §3 方法 A / `enable_lsposed.md` §4 证据 2）

```
72def9b000-72deff6000 r-xp ... /data/app/~~P1RnnO2_k5TIGLoW0aPuIQ==/com.roro.tablethook-ZB9dfCVx7Jm54SJtLTE7dQ==/lib/arm64/libdexkit.so
72deff9000-72deffc000 r--p ... /data/app/.../com.roro.tablethook-.../lib/arm64/libdexkit.so
72defff000-72df000000 rw-p ... /data/app/.../com.roro.tablethook-.../lib/arm64/libdexkit.so
```
> 主进程 PID 18591（u999，uid <CLONE_UID>）的 `/proc/maps` 内 `com.roro.tablethook` 的 `libdexkit.so` 命中 3 条（`grep -icE "roro|libdexkit" /proc/18591/maps` = 3），且**登录后复测仍命中**（verify_login_success.md §5）。

### 铁证 2 — Hook 生效日志：`微信平板登录模式已启用`
（来源：`enable_lsposed.md` §4 证据 1 / `restart_u999.md` §3 方法 B）

```
01:32:09.655 18591 D VectorModuleManager: Loading module com.roro.tablethook
01:32:09.676 18591 D VectorModuleManager: Loaded module com.roro.tablethook successfully.
01:32:11.999 18591 I TabletHook: com.roro.tablethook: DexKit 微信平板判定候选：关键词=2，签名=1
01:32:12.143 18591 I TabletHook: com.roro.tablethook: DexKit 微信副设备登录资格候选：关键词=1，签名=1
01:32:12.145 18591 I TabletHook: com.roro.tablethook: 微信平板登录模式已启用
```

### 铁证 3 — 登录落地硬证据：`autoauth.cfg` 0→1090B、`EnMicroMsg.db` 5.2MB、数据目录 1.3G
（来源：`verify_login_success.md` §1）

```
$ adb shell "su -c 'wc -c /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg 2>/dev/null'"
1090 /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg

$ adb shell "su -c 'ls -la /data/user/999/com.tencent.mm/MicroMsg/*/EnMicroMsg.db 2>/dev/null'"
-rw------- 1 <CLONE_UID> <CLONE_UID> 5239808 2026-10-03 02:00 \
  /data/user/999/com.tencent.mm/MicroMsg/fef34641effc9e0c6af9528b23e4fabd/EnMicroMsg.db   (≈5.2 MB)

$ adb shell "su -c 'du -sh /data/user/999/com.tencent.mm/ 2>/dev/null'"
1.3G	/data/user/999/com.tencent.mm/
```
> 三个判据**全部命中**。当前屏幕停在微信主聊天界面 `com.tencent.mm.ui.LauncherUI`（无 beta / 二维码 / 登录弹窗），`LoginAsExDeviceUI` 已于 01:59:31 被销毁（扫码消费、登录流程结束）。

### 铁证 4 — 完整踩坑史（7 次失败 → 成功）
（来源：`reboot_zygisk_recovery.md`、`api_incompat.md`、`module_verify2.md`、`restart_u999.md`、`enable_lsposed.md`）

1. **Zygisk rolling-back**：重启前 Zygisk 异常，处于 `rolling-back` 保护模式（`zygote crashes too many times, rolling-back`，无 `zygiskd` 守护进程）。→ 经 `adb reboot` 恢复，zygiskd 正常加载。
2. **API 100 vs 102 不兼容**：旧 LSPosed v1.9.2（7024）只支持 **Modern API 100**；TabletHook 用 **API 102** 的无参构造 `XposedModule()`，LSPosed 反射带参构造抛 `NoSuchMethodException: ...TabletHook.<init> [XposedInterface, ModuleLoadedParam]` → 模块类未加载。
   - 旧模块 `top.hookvip.wxtablet`（wxtablet）虽显示入口但**完全不含平板登录协议层 Hook**（`checkloginaspad` / `inTabletEnv`），即使启用也绕不过 beta 资格校验。
3. **LSPosed 被禁用 / 框架替换**：升级为 **Vector v2.2（API 102）** 取代 LSPosed；保持 `zygisk_vector` ENABLED、`zygisk_lsposed` DISABLED 防冲突。
4. **模块未装到 user 999**：`pm list packages --user 999` 中最初**未列出** `com.roro.tablethook`（仅 user 0 侧装好）。→ 补装 `pm install-existing --user 999 com.roro.tablethook` → `Package ... installed for user: 999`。
5. **缓存未刷新**：首次 `am start` 后框架已 attach（`[anon:InternalMmapVector]` 在 maps）但模块类未加载——Vector 守护进程缓存只有 01:20 的 user-0 记录，缺 u999 变体（模块在本会话内才 install 到 999，晚于守护进程扫描）。→ 对 `com.roro.tablethook` 执行 `modules disable` → `modules enable` 刷新缓存，再 force-stop + start，01:32 起 u999 进程开始加载。
6. （前期）`wxtablet` 仅 UI 层生效、协议层缺失 → 维持 beta 弹窗 `The beta version is only for eligible users`，判为模块无效。
7. （前期）u999 环境判定缺失 / scope 未覆盖 user 999 → 经 Vector CLI 将 `com.tencent.mm`（User 0 与 User 999）均加入 Scope 作用域后解决。

> 最终：以上 7 类问题逐一清零 → 扫码登录成功落地。

---

## 三、可复现步骤（供后续重置 / 复现）

> 适用于「已刷入 Vector v2.2、已安装 `com.roro.tablethook` APK、设备已 root」的前提。

1. **启用 LSPosed/Vector 模块**：在 Vector（或 LSPosed）中启用 `com.roro.tablethook`，禁用冲突模块（`zygisk_lsposed` 保持 DISABLED）。
2. **装到 user 999 作用域**：
   ```
   pm install-existing --user 999 com.roro.tablethook
   ```
   并将 `com.tencent.mm`（User 0 与 User 999）加入 Scope。
3. **刷缓存**（若模块晚于守护进程扫描安装，或改了 enabled 状态）：
   ```
   /data/adb/modules/zygisk_vector/cli modules disable com.roro.tablethook
   /data/adb/modules/zygisk_vector/cli modules enable  com.roro.tablethook
   ```
4. **重启 u999 微信**：
   ```
   am force-stop --user 999 com.tencent.mm
   am start --user 999 -n com.tencent.mm/.ui.LauncherUI
   ```
5. **拉起平板登录二维码页**：
   ```
   am start --user 999 -n com.tencent.mm/.plugin.login_exdevice.ui.LoginAsExDeviceUI
   ```
6. **手机微信扫码** → 微信主界面 `LauncherUI` 出现即登录成功。
7. **校验落盘**：`wc -c /data/user/999/com.tencent.mm/MicroMsg/autoauth.cfg`（>0B）、`EnMicroMsg.db` 存在（≈5.2MB）、`du -sh /data/user/999/com.tencent.mm/` 增长。

---

## 四、user 0 未受影响 ✅

（来源：`verify_login_success.md` §4）

```
$ adb shell "su -c 'wc -c /data/user/0/com.tencent.mm/MicroMsg/autoauth.cfg'"
810 /data/user/0/com.tencent.mm/MicroMsg/autoauth.cfg

$ adb shell "su -c 'ls -la /data/user/0/com.tencent.mm/MicroMsg/*/EnMicroMsg.db 2>/dev/null'"
-rw------- 1 u0_a236 u0_a236 11323392 2026-10-03 00:42 \
  /data/user/0/com.tencent.mm/MicroMsg/4905a07ab609af04a30c9c7554ce758d/EnMicroMsg.db   (≈11.3 MB)

$ adb shell "ps -A | grep -E 'u0.*tencent'"
u0_a236  11538  ... S com.tencent.mm           (主进程)
u0_a236  11828  ... S com.tencent.mm:push
u0_a236  12118  ... S com.tencent.mm:tools
```
> user 0：autoauth.cfg=**810B**、EnMicroMsg.db≈**11.3MB**、主进程存活 → **登录态完好，本次操作未波及**。

---

## 五、一句话结论

**登录成功且已真正落地**：`autoauth.cfg` 由 0→1090B、`EnMicroMsg.db` 已生成(5.2MB)、1.3G 数据目录；`LoginAsExDeviceUI` 已销毁、当前停于微信主聊天界面、无 beta 弹窗；TabletHook（Vector API 102）仍注入 u999；user 0 完好。
