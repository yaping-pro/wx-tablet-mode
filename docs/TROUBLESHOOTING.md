# 故障排查手册 (Troubleshooting Guide)

本手册汇总了在微信安卓平板模式多端多登配置过程中常见的典型异常、根因剖析与标准处置步骤。

---

## 1. 常见故障矩阵 (Quick Diagnostics)

| 故障现象 | 根因分类 | 核心表现 | 处置方法 |
| :--- | :--- | :--- | :--- |
| **弹窗提示 Beta 版本** | 服务端拦截 / Tinker 热更 | 登录提示 "The beta version is only for eligible users" | 换装官方基线 `0x28004e32`，隔离 Tinker 补丁 |
| **未弹二维码，直跳密码页** | 协议 Hook 未注入 | 启动后直接进入常规手机号/密码登录页 | 检查 Hook 作用域与 `pm install-existing` |
| **认证态挂死 (`auth_ishold=true`)** | 历史中断死锁 | 二维码无法刷新，频繁网络异常 | 运行 `scripts/reset_wechat_auth.sh` 移走认证态 |
| **Binder DAC 拒绝 (`2147483646`)** | 权限/SELinux 拒绝 | 终端抛出 `Failed transaction (2147483646)` | 重定向命令输出至 `/dev/null` 或 `/data/local/tmp/` |
| **冷启动无法进入 (`Direct Boot`)** | 锁屏凭据 CE 锁定 | 手机重启后后台进程无法启动、找不到数据目录 | 首次开机人工解锁，或专用备用机移除锁屏密码 |

---

## 2. 深度排错指南 (Detailed Resolution)

### 2.1 故障一：Beta 弹窗拦截 ("The beta version is only for eligible users")
- **根因**:
  1. 当前微信 APK 属于内测 Beta 通道（如 `0x28004e38`），被腾讯服务端检测并阻断；
  2. 即使初始安装为正式版，微信内置的 **Tinker 热修复框架** 静默下载并加载了热更补丁，将运行时 `clientversion` 动态抬高到 Beta 级别。
- **解决步骤**:
  1. 验证基础 APK 校验和：
     ```bash
     md5sum $(pm path com.tencent.mm | sed 's/^package://')
     # 官方正式版 8.0.78 MD5: 846b411199ae49d335d31b3a17036440
     ```
  2. 执行 Tinker 补丁隔离：
     ```bash
     bash scripts/quarantine_tinker.sh
     ```
  3. 执行认证态重置：
     ```bash
     bash scripts/reset_wechat_auth.sh
     ```

### 2.2 故障二：未弹二维码，直接跳出手机号密码登录界面
- **根因**:
  微信未被识别为副设备（Pad）。通常因为外部协议 Hook（如 `com.roro.tablethook`）未在目标用户进程中被加载。
- **排查命令**:
  1. 检查模块是否安装在对应用户空间（尤其 Android 多用户/应用分身）：
     ```bash
     pm list packages --user $TARGET_USER com.roro.tablethook
     ```
     若未列出，执行：
     ```bash
     pm install-existing --user $TARGET_USER com.roro.tablethook
     ```
  2. 检查框架 Scope 勾选：
     在 Vector 或 LSPosed 管理器中，确认已为目标用户下的微信勾选启用该模块。

### 2.3 故障三：认证态死锁与挂起 (`auth_ishold=true`)
- **根因**:
  先前的登录流程中途发生异常崩溃或强行终止，导致微信在 `shared_prefs/auth_hold_prefs.xml` 中将认证标记置为保留挂起状态。后续每次尝试登录均被本地直接判定为中断态。
- **解决方案**:
  执行白纸化认证态重置：
  ```bash
  bash scripts/reset_wechat_auth.sh
  ```
  该脚本会将 `autoauth.cfg` 和 `auth_hold_prefs.xml` 移至带时间戳的安全备份目录，强制微信重新生成白纸态登录流程。

### 2.4 故障四：`Failed transaction (2147483646)`
- **根因**:
  在 root shell 中使用 `am` 或 `pm` 命令时，若将输出直接重定向到了 root 独占权限的私有目录（例如 `/data/adb/`），Android 系统框架服务（运行在 `system` 进程）在向该文件写入输出流时触发 Linux DAC 权限拒绝，返回错误码 `2147483646`。
- **处置原则**:
  所有脚本中的 `am` / `pm` 命令输出应一律重定向至 `/dev/null`，或全局可写的 `/data/local/tmp/`。

### 2.5 故障五：设备重启后后台进程无法自启 (Direct Boot CE 限制)
- **根因**:
  Android 采用基于文件加密 (FBE)。在用户未输入锁屏密码前，凭据加密储存空间 (Credential Encrypted, CE) 处于锁定状态，微信的 `/data/user/0/com.tencent.mm/` 数据目录不可读写。
- **处理建议**:
  - 对于作为常驻多端多登的专用备用手机/开发机，可在系统设置中移除锁屏密码（设置为“无锁屏”），使系统在开机后即刻解密存储。
