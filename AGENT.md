# AGENT.md — Autonomous Deployment Runbook for `wx-tablet-mode`

> **Audience**: An AI coding agent (omp / Claude Code / Codex / any shell-capable agent) that the
> user has handed a freshly rooted, USB-debugging-enabled Android device plugged into this machine.
>
> **Contract**: Follow this file top-to-bottom. Do **not** ask clarifying questions. Every step gives
> the exact command, the expected output, and the abort/rollback condition. If a hard gate fails,
> STOP and report — never improvise around it.

---

## 0. Hard gates & safety rails (read first — never violate)

1. **You do NOT grant login entitlement.** The pad-login entitlement comes **only** from a user-supplied
   external protocol hook (e.g. `com.roro.tablethook`). This repo ships `PadDisguise` (appearance) and
   governance scripts only. See [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md).
2. **HARD GATE — external hook must be present**: before declaring success, you MUST verify the external
   hook package is installed and scoped. If it is absent, STOP and tell the user to obtain it (point to
   [`docs/EXTERNAL_HOOK_SPEC.md`](docs/EXTERNAL_HOOK_SPEC.md)). Never pretend to install or fabricate it.
3. **Never `am force-stop` a WeChat that is already logged in** for the target user — it breaks the live
   pad session. `scripts/reset_wechat_auth.sh` force-stops only as part of a *clean-slate reset*, which is
   only appropriate on a device that is **not** in a working logged-in state.
4. **Never bind any service to `0.0.0.0`.** Loopback (`127.0.0.1`) only.
5. **Never delete `/data/adb/service.d` scripts.**
6. **Ask before flashing or patching any APK** (e.g. installing/downgrading WeChat). Verification commands
   are read-only; only the explicit install/reset steps mutate state, and they are gated below.

---

## 1. Preflight (resolve device, assert every prerequisite)

Work from this repo root. All scripts accept `DEVICE_ID` and `TARGET_USER` env vars.

```bash
# Resolve the device — NEVER hardcode a serial.
adb devices -l
# Pick the single connected device. If more than one, set DEVICE_ID explicitly:
#   export DEVICE_ID=xxxxxxxx
# Default target user is 0 (physical device). For a cloned profile set:
#   export TARGET_USER=999
adb get-state                       # expect: device
adb shell su -c 'id -u'             # expect: 0        (root via Magisk/KernelSU)
```

Run the bundled preflight (covers root, framework, official-APK hash, hook, PadDisguise):

```bash
bash scripts/preflight_check.sh
```

Then assert each item explicitly and **report what is MISSING with remediation**:

| Check | Probe | Pass condition | If MISSING → remediation |
| :--- | :--- | :--- | :--- |
| Device resolved | `adb devices -l` | exactly one `device` online | User must connect/authorize the intended device |
| Root | `adb shell su -c 'id -u'` | `0` | Root the device (Magisk/KernelSU) first |
| Magisk/KernelSU | `adb shell su -c 'test -d /data/adb/modules && echo ok'` | `ok` | Install Magisk/KernelSU |
| Zygisk + LSPosed/Vector | `adb shell su -c 'test -d /data/adb/modules/zygisk_vector -o -d /data/adb/modules/zygisk_lsposed && echo ok'` | `ok` | Install Zygisk + Vector (API-102) or LSPosed and enable Zygisk |
| Official WeChat build | `adb shell su -c 'md5sum "$(pm path --user "$TARGET_USER" com.tencent.mm | sed s/package://)"'` | MD5 `846b411199ae49d335d31b3a17036440` | See Step 2 (verify/install official `8.0.78 / 0x28004e32`) |
| External hook present | `adb shell pm list packages --user "$TARGET_USER" com.roro.tablethook` | prints the package | **HARD GATE** → STOP, tell user to install+scope the hook (see `docs/EXTERNAL_HOOK_SPEC.md`) |

---

## 2. Autonomous steps (in order)

> Idempotent steps are marked ✅ — safe to re-run. Mutating steps are marked ⚠️.

### Step A ✅ — Official-package verify (MD5 + SHA-256)

```bash
APK=$(adb shell pm path --user "$TARGET_USER" com.tencent.mm | sed 's/^package://' | tr -d '\r')
echo "APK path: $APK"
adb shell su -c "md5sum \"$APK\""
# Expected MD5 : 846b411199ae49d335d31b3a17036440
# Expected SHA : 41f7dc1f720767fa78fa20dd13ea034b817bbf6ebd23dfd1324c647499c9c1ba
adb shell su -c "sha256sum \"$APK\""
```

- **Expected output**: MD5/SHA-256 match the values above; `tinker_patch_version_key` last byte is `32`.
- **Abort condition**: Beta build (`0x28004e38`) or any non-matching hash.
- **Remediation (⚠️ ask first before installing/downgrading WeChat)**:
  install the official `8.0.78 / 0x28004e32` arm64 build via
  `adb install -r -d <official_apk>` (keep data, allow downgrade). Official CDN:
  `https://dldir1v6.qq.com/weixin/android/weixin8078android3180_0x28004e32_arm64.apk`
  (280,614,450 bytes; verify SHA-256 before install).

### Step B ✅ — Clean auth-state reset (parameterized user)

```bash
TARGET_USER="${TARGET_USER:-0}" bash scripts/reset_wechat_auth.sh
```

- **Expected output**: `[+] Reset complete.` and `autoauth.cfg: ABSENT (clean)` / `auth_hold_prefs.xml: ABSENT (clean)`.
- **Abort condition**: script errors before the verify step.
- **Idempotent**: ✅ safe to re-run; it only moves stale auth files into a timestamped backup.

### Step C ⚠️ — Install PadDisguise APK + enable scope for `com.tencent.mm`

```bash
# Prefer the prebuilt release asset; fall back to a locally built APK.
adb install -r wx-tablet-mode-v1.0.1-universal.apk   # or: app/build/outputs/apk/release/app-release.apk
```

- **Expected output**: `Success`.
- **Then enable scope**: in LSPosed/Vector Manager → enable module `com.wx.pad` (PadDisguise) →
  add `com.tencent.mm` to its Scope. (No CLI for this; if a manager exposes an intent/API, use it;
  otherwise instruct the user — this is the one step requiring a tap in the manager UI.)
- **Abort condition**: install fails (e.g. device not rooted / module framework missing) → go back to Preflight.

### Step D ✅ — Quarantine Tinker patches

```bash
TARGET_USER="${TARGET_USER:-0}" bash scripts/quarantine_tinker.sh
```

- **Expected output**: `[+] Quarantine complete.` (or "No patch-* directories currently active.")
- **Abort condition**: none fatal; warn if patches were found and moved.
- **Idempotent**: ✅ safe to re-run.

### Step E ✅ — Verify external hook is present (HARD GATE)

```bash
adb shell pm list packages --user "$TARGET_USER" com.roro.tablethook
# Also confirm it is scoped in the manager (no CLI; ask user to confirm scope includes com.tencent.mm).
```

- **Expected output**: the hook package is listed.
- **Abort condition (HARD GATE)**: package absent → **STOP**, report:
  "External pad-login hook not installed. This repo does not ship it. Obtain a compatible hook
  (see `docs/EXTERNAL_HOOK_SPEC.md`) and scope it to `com.tencent.mm`, then re-run." Do NOT continue.

### Step F ⚠️ — Launch QR login

```bash
adb shell su -c "am force-stop --user $TARGET_USER com.tencent.mm"   # only if NOT already logged in
sleep 2
adb shell su -c "am start --user $TARGET_USER -n com.tencent.mm/.ui.LauncherUI"
```

- **Expected output**: WeChat launches and shows the **tablet login QR code** (not phone/password login).
- **Abort condition**: phone/password login appears → external hook not active (re-check Step E) or
  wrong WeChat build (re-check Step A).

---

## 3. Verification — prove success, then report

```bash
# 1. Logcat signature proving PadDisguise + tablet mode engaged:
adb logcat -d | grep -E "微信平板登录模式已启用|微信副设备登录资格候选|微信平板判定候选" | tail -20
# 2. auth file grew after a successful scan:
adb shell su -c "ls -l /data/user/$TARGET_USER/com.tencent.mm/MicroMsg/autoauth.cfg"
```

- **Success criteria**:
  - Logcat contains `微信平板登录模式已启用`.
  - `autoauth.cfg` grew from 0 bytes to ~1114 bytes after the primary device confirms the scan.
  - WeChat enters `LauncherUI` (dual-pane tablet layout) and stays connected.

**Report back to the user**:
1. Device resolved + root/framework asserted (yes/no).
2. WeChat build verified (`0x28004e32`, MD5 + SHA-256 matched).
3. External hook present + scoped (package name).
4. PadDisguise installed + scoped to `com.tencent.mm`.
5. Tinker patches quarantined (count moved / none).
6. Login QR shown + `autoauth.cfg` grew to N bytes + logcat signature captured.
7. Any step that was skipped or needs a human tap (e.g. enabling scope in the manager UI).

---

## 4. Safety rails summary (must obey)

- Never `am force-stop` a logged-in WeChat (breaks pad session) — force-stop only during a clean reset
  (Step B) or before a fresh launch on a non-logged-in device (Step F).
- Never bind any service to `0.0.0.0` (loopback only).
- Never delete `/data/adb/service.d` scripts.
- Ask before flashing/patching any APK.
- Do not fabricate or install the external hook; verify-only (HARD GATE Step E).

---

## 5. Idempotency

Safe to re-run without side effects: **Step A** (verify), **Step B** (reset — moves only stale files to
a new timestamped backup), **Step D** (quarantine — idempotent), **Step E** (verify hook), **Preflight**.
Not idempotent / state-changing: **Step C** (APK install — use `-r` to replace), **Step F** (launch).
