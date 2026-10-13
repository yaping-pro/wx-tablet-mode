# 贡献指南 (Contributing Guide)

感谢您关注 `wx-tablet-mode`！本项目致力于在合规、干净、透明的前提下，研究与实现 Android 微信平板副设备登录的外观伪装与第一方登录资格 Hook。

在提交 Issue 或 Pull Request 前，请仔细阅读以下规范。

---

## 核心原则与项目边界 (Core Principles & Boundaries)

1. **纯开源第一方实现与合规衍生 (First-Party Open Source Implementation)**：
   - 本项目核心代码（`app/`）基于纯开源逆向与动态 Hook（DexKit + LSPosed/Vector）。
   - **严禁提交任何来自微信官方或其他商业软件的专有二进制代码、反编译原码或未授权资源**。
   - 外部 Hook 兼容规范请参考 [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)。
2. **纯学术研究与个人使用 (Research & Personal Use Only)**：
   - 严禁提交任何破坏性功能、商业群控、营销自动化、恶意攻击或破坏服务可用性的代码。
   - 请参阅 [`DISCLAIMER.md`](DISCLAIMER.md) 了解免责声明。
3. **零凭据与敏感信息防护 (Zero Secrets / Zero PII)**：
   - 严禁在提交历史中包含任何真实设备序列号、私网 IP、微信 UIN、Ticket、认证备份文件（如 `autoauth.cfg`）或 API Token。
   - 请参阅 [`SECURITY.md`](SECURITY.md) 了解安全政策。

---

## 提交规范 (Commit Convention)

遵循 Conventional Commits 规范，常见前缀如下：

- `feat(disguise)`: 外观伪装相关功能
- `feat(hook)`: 第一方登录 Hook 相关功能
- `fix`: 缺陷修复
- `docs`: 文档完善与翻译更新
- `refactor`: 代码重构（不改变外部行为）
- `ci`: GitHub Actions / 构建流水线调整
- `chore`: 杂项、依赖升级

Commit Message 格式示例：
```text
feat(hook): improve dynamic opcode matching for WeChat 8.0.x
fix(disguise): correct density dpi calculation on foldable screens
docs: update tablet login troubleshooting guide
```

---

## 本地构建与验证 (Build & Verification)

在提交 PR 前，请确保项目可以通过 Gradle 编译并生成 Release APK：

```bash
# 检查编译与代码风格
./gradlew check

# 构建 Release APK
./gradlew assembleRelease
```

---

## 行为准则 (Code of Conduct)

请保持友善、专业、理性的技术交流氛围。我们专注于工程技术与个人数据自主权，拒绝任何形式的人身攻击与滥用行为。
