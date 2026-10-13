# 免责声明 (Disclaimer)

## 中文声明

1. **研究与学习用途**：本项目（`wx-tablet-mode`，包括相关文档、Shell 诊断脚本及 `PadDisguise` 开源辅助模块）仅供个人安全研究、逆向工程学习以及在自有受控设备上探索多端协同机制。
2. **账号与封禁风险**：微信属于腾讯科技（深圳）有限公司旗下产品与专有服务。微信安全风控系统对客户端运行环境、系统属性改写、Zygisk/LSPosed 模块注入及非官方设备登录态具有多重服务端检测与风控机制。使用本方案可能面临账号受限、强制下线或封禁等不可逆风险，使用者须自行承担全部后果与法律责任。
3. **技术与功能范围界定**：本项目自 v1.0.2 起内置第一方 Pad 登录资格 Hook (`PadLoginHook`) 与外观伪装模块 (`PadDisguise`)。本项目属于技术研究与学习实现，不保证在微信所有未来版本或特定设备上必定登录成功；核心扫码登录能否长期维持亦取决于微信服务端的动态风控策略。使用者须充分了解 Hook 商业软件的合规与服务条款边界，并承担个人账号使用风险。
4. **严禁用于非法用途**：严禁将本项目任何部分用于商业群控、营销轰炸、外挂分发、非法爬虫、黑灰产业或任何违反中华人民共和国法律法规及《微信个人账号使用规范》之行为。项目发起者与贡献者不对任何滥用行为承担法律责任。

---

## English Notice

1. **Educational & Research Purpose**: This repository is provided strictly for personal learning, reverse-engineering study, and device-management exploration on personal hardware.
2. **Account & Service Risks**: WeChat is a proprietary communication service operated by Tencent. Tampering with runtime process environments, spoofing system properties, or injecting Xposed modules may trigger risk-control defenses, resulting in account suspension or termination. Users assume all responsibility and liability.
3. **Functional Scope**: As of v1.0.2, this repository includes both a first-party pad-login qualification hook (`PadLoginHook`) and an appearance disguise helper (`PadDisguise`). This is personal experimental research and does not guarantee successful login on all future WeChat releases or hardware configurations. Users are solely responsible for compliance with WeChat terms of service.
4. **Prohibition of Malicious Use**: Any commercial mass marketing, spamming, botting, or malicious activities using this project are strictly prohibited.
