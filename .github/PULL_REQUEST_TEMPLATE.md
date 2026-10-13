## 变更概述 / Pull Request Overview

<!-- 请简明扼要地描述本 PR 解决的问题或引入的新特性 / Briefly describe what this PR accomplishes -->

### 关联 Issue / Related Issues
<!-- 如有，请使用 Closes #123 或 Fixes #123 关联 / Link relevant issues -->
Closes #

---

## 变更类型 / Type of Change

- [ ] 🐛 Bug 修复 / Bug fix (non-breaking change which fixes an issue)
- [ ] 💡 新功能 / New feature (non-breaking change which adds functionality)
- [ ] 🛠️ 重构与代码治理 / Refactoring & cleanups
- [ ] 📝 文档更新 / Documentation update
- [ ] ⚙️ CI / 构建流水线调整 / CI & workflow changes
- [ ] 📱 设备机型伪装适配 / Device disguise metrics update

---

## 测试与验证 / How Has This Been Tested?

请描述您是在何种物理机或测试环境中验证该改动的：
- **测试机型 (Device Model)**: 
- **Android 系统与版本 (OS & Version)**: 
- **Root 框架 (Magisk / KernelSU / APatch)**: 
- **LSPosed / Vector 版本**: 
- **微信测试版本与构建号 (WeChat Version & Build Code)**: 
- **验证结果 (Results)**:
  - [ ] 运行 `./gradlew check` 无报错
  - [ ] 运行 `./gradlew assembleRelease` 成功构建 APK
  - [ ] 在实机上成功安装并正常进入平板模式二维码界面

---

## 贡献合规自查清单 / Contributor Checklist

在提交前请仔细核对以下每一项：

- [ ] **零凭据与隐私保护 (Zero Secrets / Zero PII)**: 代码、文档、注释与提交历史中绝无任何真实 Token、私网 IP、密钥、真实微信号、UIN、手机号或 `autoauth.cfg` 等运行时凭据。
- [ ] **无商业专有二进制 (No Proprietary Binaries)**: 绝未引入任何来自微信官方或其他闭源商业软件的二进制文件或反编译受保护代码。
- [ ] **遵守代码规范与约定**: 遵循本项目的编码风格与 Conventional Commits 提交命名规范。
- [ ] **文档同步**: 若涉及用户可见改动或排错逻辑，已同步更新相关 Markdown 文档。
- [ ] **开源许可遵从 (License & DCO)**: 我确认本 PR 代码完全由我原创或依据兼容开源许可证合法引入，并同意依据本项目开源许可证 (GPL-3.0) 授权公开发布。
