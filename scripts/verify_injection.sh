#!/usr/bin/env bash
#
# verify_injection.sh — Prove that com.wx.pad (PadLoginHook) is actually injected
# into the PRIMARY WeChat process on a target device.
#
# This is the on-device counterpart to AGENT.md Step E. Package presence
# (pm list packages) is NOT sufficient proof: Vector's daemon can silently
# skip injection in clone spaces (see AGENT.md Step C cache-dance). This script
# resolves the real primary process PID and inspects two independent signals:
#
#   1. /proc/<pid>/maps — the module must be mapped into the main
#      "com.tencent.mm" process (NOT a :support/:push/:appbrand helper).
#   2. logcat — the enable signature "微信平板登录模式已启用" must appear,
#      proving PadLoginHook ran.
#
# Usage:
#   bash scripts/verify_injection.sh [--pid PID]
#
# Env:
#   DEVICE_ID    adb -s selector (optional)
#   TARGET_USER  Android user id (default 0)
#
# Exit codes:
#   0  injection proven (maps + logcat both positive)
#   1  injection NOT proven
#   2  usage / device error
# --- argument parsing -------------------------------------------------------
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



TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

# --- resolve primary WeChat PID ---------------------------------------------
if [[ -n "$PID_ARG" ]]; then
  PID="$PID_ARG"
else
  # pidof returns the primary process first; grab the first token.
  PID=$($ADB_CMD shell "su -c 'pidof com.tencent.mm'" 2>/dev/null | tr -d '\r' | awk '{print $1}')
fi

if [[ -z "$PID" || "$PID" == "0" ]]; then
  echo "[-] ERROR: could not resolve a running primary 'com.tencent.mm' process." >&2
  echo "    Is WeChat running for user $TARGET_USER? Try:" >&2
  echo "      $ADB_CMD shell su -c 'pidof com.tencent.mm'" >&2
  exit 2
fi

echo "[*] Primary WeChat process PID: $PID (user $TARGET_USER)"

# --- signal 1: module mapped in /proc/<pid>/maps ----------------------------
echo "[*] Checking /proc/$PID/maps for module com.wx.pad ..."
MAPS_HIT=$($ADB_CMD shell "su -c 'grep -E \"com\\\\.wx\\\\.pad|wx/pad\" /proc/$PID/maps'" 2>/dev/null | tr -d '\r' | grep -c . || true)

if [[ "$MAPS_HIT" -gt 0 ]]; then
  echo "[+] maps: com.wx.pad IS mapped into the primary process ($MAPS_HIT line(s))."
else
  echo "[-] maps: com.wx.pad NOT found in /proc/$PID/maps."
fi

# --- signal 2: logcat enable signature --------------------------------------
echo "[*] Checking logcat for enable signature '微信平板登录模式已启用' ..."
LOGCAT_HIT=$($ADB_CMD logcat -d 2>/dev/null | grep -c "微信平板登录模式已启用" || true)

if [[ "$LOGCAT_HIT" -gt 0 ]]; then
  echo "[+] logcat: enable signature present ($LOGCAT_HIT match(es))."
else
  echo "[-] logcat: enable signature '微信平板登录模式已启用' NOT found."
fi

# --- verdict -----------------------------------------------------------------
if [[ "$MAPS_HIT" -gt 0 && "$LOGCAT_HIT" -gt 0 ]]; then
  echo "=========================================================="
  echo "[+] VERIFIED: PadLoginHook injected & active in primary process $PID."
  echo "=========================================================="
  exit 0
else
  echo "=========================================================="
  echo "[-] NOT VERIFIED: injection incomplete."
  if [[ "$MAPS_HIT" -eq 0 ]]; then
    echo "    - module not mapped (daemon may have skipped injection; re-run"
    echo "      the Step C cache-dance in AGENT.md, then am force-stop + relaunch)."
  fi
  if [[ "$LOGCAT_HIT" -eq 0 ]]; then
    echo "    - enable signature missing (WeChat may not have restarted since install)."
  fi
  echo "=========================================================="
  exit 1
fi
