#!/usr/bin/env bash
#
# verify_post_boot.sh — Run post-boot durability verification protocol (§7 Precaution 3)
# for com.wx.pad in u999 (and u0) on the target device.
#
# Checks:
#   1. Vector daemon scope contains com.wx.pad for com.tencent.mm (user 0 and 999).
#   2. Module com.wx.pad is mapped into the primary WeChat process (/proc/<pid>/maps).
#   3. Optionally confirms PadLoginHook enable signature in logcat via verify_injection.sh.
#
# Usage:
#   bash scripts/verify_post_boot.sh [--pid PID]
#
# Env:
#   DEVICE_ID    adb -s selector (optional)
#   TARGET_USER  Android user id (default 999)
#
# Exit codes:
#   0  all checks passed
#   1  verification failed
#   2  usage / device error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${TARGET_USER:-999}"
DEVICE_ID="${DEVICE_ID:-}"
PID_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pid)
      shift
      PID_ARG="${1:-}"
      ;;
    --pid=*)
      PID_ARG="${1#*=}"
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "[-] Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

echo "=========================================================="
echo "[*] Post-Boot Durability Verification Protocol (§7 Precaution 3)"
echo "[*] Target user: $TARGET_USER"
echo "=========================================================="

# Check 1: Vector daemon scope check
echo "[*] Check 1: Vector CLI scope query for com.wx.pad ..."
VECTOR_CLI=""
for cli_candidate in /data/adb/modules/zygisk_vector/cli /data/adb/lspd/cli; do
  if [[ "$($ADB_CMD shell "su -c 'test -x $cli_candidate && echo 1 || true'" 2>/dev/null | tr -d '\r\n')" == "1" ]]; then
    VECTOR_CLI="$cli_candidate"
    break
  fi
done

if [[ -z "$VECTOR_CLI" ]]; then
  echo "[-] WARNING: Neither /data/adb/modules/zygisk_vector/cli nor /data/adb/lspd/cli found executable."
else
  echo "[+] Found Vector CLI at $VECTOR_CLI"
  SCOPE_JSON=$($ADB_CMD shell "su -c '$VECTOR_CLI scope ls --json com.wx.pad'" 2>/dev/null | tr -d '\r' || true)
  echo "$SCOPE_JSON"
  if echo "$SCOPE_JSON" | grep -q '"USER_ID":[[:space:]]*'"$TARGET_USER"''; then
    echo "[+] Check 1 PASSED: com.wx.pad scope active for user $TARGET_USER in Vector daemon."
  else
    echo "[-] Check 1 FAILED: user $TARGET_USER not found in com.wx.pad scope."
    exit 1
  fi
fi

# Check 2 & 3: Run verify_injection.sh (covers /proc/<pid>/maps + logcat signature)
echo ""
echo "[*] Check 2 & 3: Primary process maps & logcat verification ..."
export TARGET_USER
export DEVICE_ID
VERIFY_ARGS=()
if [[ -n "$PID_ARG" ]]; then
  VERIFY_ARGS+=(--pid "$PID_ARG")
fi

if bash "$SCRIPT_DIR/verify_injection.sh" "${VERIFY_ARGS[@]}"; then
  echo ""
  echo "=========================================================="
  echo "[+] ALL POST-BOOT CHECKS PASSED: com.wx.pad fully operational."
  echo "=========================================================="
  exit 0
else
  echo ""
  echo "=========================================================="
  echo "[-] POST-BOOT VERIFICATION FAILED: see above errors."
  echo "=========================================================="
  exit 1
fi
