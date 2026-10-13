# 安全政策 (Security Policy)

## 支持版本 (Supported Versions)

| 版本 | 状态 |
| :--- | :--- |
| `1.0.x` | 积极维护中 (Active) |
| `< 1.0.0` | 不受支持 |

---

## 报告安全漏洞 (Reporting a Vulnerability)

如果您在本项目所包含的源码（`PadDisguise` 辅助模块、`PadLoginHook` 核心实现）或部署/排错脚本中发现安全漏洞、凭据泄漏或越权隐患：

1. **请勿直接公开创建公共 Issue**。
2. 请通过 GitHub 平台的 **Private Vulnerability Reporting** 官方通道提交私密报告：
   - 访问链接：`https://github.com/yaping-pro/wx-tablet-mode/security/advisories/new`
   - 或进入本仓库 **Security** 标签页，点击 **Report a vulnerability**。
3. 报告中请包含：
   - 受影响的文件及具体行号；
   - 漏洞复现步骤与概念验证 (PoC)；
   - 潜在威胁场景及修复建议。

维护者将在收到报告后 72 小时内确认并评估风险。

---

## 敏感信息防护规范 (Credential & PII Hygiene)

本项目严格执行零凭据与零个人敏感信息 (Zero PII/Secrets) 提交规范：

- 严禁在任何脚本、配置文件或文档中硬编码敏感标识符（包括 Tailscale Key、AWS Key、GitHub PAT、私网真实 IP、微信真实 ID / UIN、手机号或设备序列号）。
- 本地调试运行时生成的备份文件（如 `/data/adb/wx_stream/backup_auth_*/` 下的 `autoauth.cfg`）包含二进制认证 Ticket 与凭据哈希，**绝对禁止**提交至公共仓库或日志 Issue。

---

## 官方发布证书公钥指纹 (Official Release Certificate Fingerprint)

为防范供应链投毒与未授权第三方二次打包，本仓库通过 GitHub Actions 自动化构建发布的每一个正式 Release APK（`wx-tablet-mode-*-arm.apk`）均由受保护的专有签名密钥签署，并在 CI 门禁中硬性断言其签名证书指纹与 4 字节 `zipalign` 对齐。

### 预期签名公钥证书 SHA-256 指纹
```text
76:AD:A6:29:EA:2A:12:C6:77:67:22:52:15:63:2B:19:F8:31:78:F3:4F:92:C2:79:E6:44:6E:BC:25:84:30:C1
```

### 本地校验方法 (Verification Command)
用户下载 APK 后可在本地终端运行以下命令校验真伪：
```bash
# 方法 1：使用 Android SDK apksigner 验证 (推荐)
apksigner verify --print-certs wx-tablet-mode-*-arm.apk | grep -i "SHA-256"

# 方法 2：使用 JDK keytool 验证
keytool -printcert -jarfile wx-tablet-mode-*-arm.apk | grep -i "SHA256"
```
若输出的证书指纹与上方公示指纹不一致，**严禁安装**并请立即通过安全通道向维护者通报。
