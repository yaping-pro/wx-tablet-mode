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
