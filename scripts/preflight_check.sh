#!/usr/bin/env bash
#
# preflight_check.sh — Environment readiness check for wx-tablet-mode.
#
# Inspects target Android device / local environment via adb shell:
# 1. Root privilege (su execution)
# 2. Xposed / Zygisk framework (Vector API-102 or LSPosed)
# 3. WeChat base APK version (matches 8.0.78 / 0x28004e32 hash)
# 4. External protocol hook module (e.g. com.roro.tablethook)
# 5. Appearance disguise module (com.wx.pad)
#
set -euo pipefail

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

echo "=========================================================="
echo "  wx-tablet-mode: Preflight Environment Readiness Check   "
echo "  Target User: $TARGET_USER                               "
echo "=========================================================="

# Check adb connection
if ! $ADB_CMD get-state >/dev/null 2>&1; then
  echo "[-] ERROR: adb device not found or unauthorized." >&2
  echo "    Please verify USB debugging / adb connection." >&2
  exit 1
fi
echo "[+] ADB connection: OK"

# Check root privilege
ROOT_CHECK=$($ADB_CMD shell "su -c 'id -u'" 2>/dev/null || true)
if [[ "$ROOT_CHECK" != "0" ]]; then
  echo "[-] ERROR: Root privilege check failed (su -c 'id -u' != 0)." >&2
  echo "    wx-tablet-mode requires Magisk/KernelSU root access." >&2
  exit 2
fi
echo "[+] Root access (UID 0): OK"

# Check WeChat installation in target user
MM_PATH=$($ADB_CMD shell "pm path --user $TARGET_USER com.tencent.mm" 2>/dev/null | tr -d '\r' | sed 's/^package://' || true)
if [[ -z "$MM_PATH" ]]; then
  echo "[-] ERROR: com.tencent.mm not installed for user $TARGET_USER." >&2
  exit 3
fi
echo "[+] WeChat package found: $MM_PATH"

# Check official base APK version hash
EXPECTED_MD5="846b411199ae49d335d31b3a17036440"
ACTUAL_MD5=$($ADB_CMD shell "su -c 'md5sum \"$MM_PATH\"'" 2>/dev/null | awk '{print $1}' | tr -d '\r' || true)

if [[ "$ACTUAL_MD5" == "$EXPECTED_MD5" ]]; then
  echo "[+] WeChat APK baseline match: 8.0.78 (0x28004e32, MD5: $ACTUAL_MD5)"
else
  echo "[!] WARNING: WeChat APK MD5 ($ACTUAL_MD5) does not match tested baseline ($EXPECTED_MD5)."
  echo "    Ensure official 8.0.78 arm64 release is installed to avoid Beta intercept."
fi

# Check Tinker patch status
TINKER_PATCHES=$($ADB_CMD shell "su -c 'ls -d /data/user/$TARGET_USER/com.tencent.mm/tinker/patch-* 2>/dev/null'" || true)
if [[ -n "$TINKER_PATCHES" ]]; then
  echo "[!] WARNING: Active Tinker hotfix patches detected:"
  echo "$TINKER_PATCHES" | sed 's/^/      /'
  echo "    Run scripts/quarantine_tinker.sh to prevent automatic clientVersion upgrades to Beta."
else
  echo "[+] Tinker hotfix patches: None (clean base version)"
fi

# Check Vector / LSPosed framework
FRAMEWORK_OK=0
if $ADB_CMD shell "su -c 'test -d /data/adb/modules/zygisk_vector'" 2>/dev/null; then
  echo "[+] Framework detected: Vector (API-102 compatible)"
  FRAMEWORK_OK=1
elif $ADB_CMD shell "su -c 'test -d /data/adb/modules/zygisk_lsposed'" 2>/dev/null; then
  echo "[!] Framework detected: LSPosed (check API compatibility with your hook module)"
  FRAMEWORK_OK=1
fi

if [[ "$FRAMEWORK_OK" -eq 0 ]]; then
  echo "[!] WARNING: Neither Vector nor LSPosed found under /data/adb/modules/."
fi

# Check External Protocol Hook module (e.g. com.roro.tablethook)
HOOK_INSTALLED=$($ADB_CMD shell "pm list packages --user $TARGET_USER com.roro.tablethook" 2>/dev/null | tr -d '\r' || true)
if [[ -n "$HOOK_INSTALLED" ]]; then
  echo "[+] External tablet protocol hook: com.roro.tablethook installed for user $TARGET_USER"
else
  echo "[!] NOTE: com.roro.tablethook NOT found for user $TARGET_USER."
  echo "    Remember: wx-tablet-mode does NOT grant login privileges."
  echo "    Ensure your external protocol hook is installed and scoped."
fi

# Check PadDisguise module
PAD_INSTALLED=$($ADB_CMD shell "pm list packages --user $TARGET_USER com.wx.pad" 2>/dev/null | tr -d '\r' || true)
if [[ -n "$PAD_INSTALLED" ]]; then
  echo "[+] PadDisguise helper: com.wx.pad installed for user $TARGET_USER"
else
  echo "[*] PadDisguise helper (com.wx.pad) not installed yet (optional layout helper)."
fi

echo "=========================================================="
echo "  Preflight checks complete.                              "
echo "=========================================================="
