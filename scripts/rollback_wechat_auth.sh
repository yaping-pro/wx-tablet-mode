#!/usr/bin/env bash
#
# rollback_wechat_auth.sh — Restore previous WeChat authentication state from backup.
#
# Usage:
#   bash scripts/rollback_wechat_auth.sh [TIMESTAMP]
#
# If TIMESTAMP is not specified, uses the latest backup in /data/adb/wx_stream/backup_auth_*.
#
set -euo pipefail

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
TS="${1:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

echo "=========================================================="
echo "  wx-tablet-mode: Rollback WeChat Authentication State    "
echo "  Target User: $TARGET_USER                               "
echo "=========================================================="

if [[ -z "$TS" ]]; then
  echo "[*] Discovering latest backup directory on device..."
  LATEST_BACKUP=$($ADB_CMD shell "su -c 'ls -td /data/adb/wx_stream/backup_auth_* 2>/dev/null | head -1'" | tr -d '\r')
  if [[ -z "$LATEST_BACKUP" ]]; then
    echo "[-] ERROR: No auth backups found under /data/adb/wx_stream/." >&2
    exit 1
  fi
  BACKUP_DIR="$LATEST_BACKUP"
else
  BACKUP_DIR="/data/adb/wx_stream/backup_auth_${TS}"
fi

echo "[*] Using backup source: $BACKUP_DIR"

MM_DATA_DIR="/data/user/${TARGET_USER}/com.tencent.mm"

# Dynamically discover UID/GID of the WeChat data directory
echo "[*] Detecting user UID/GID for $MM_DATA_DIR..."
MM_OWNER=$($ADB_CMD shell "su -c 'stat -c \"%u:%g\" \"$MM_DATA_DIR\" 2>/dev/null || ls -ld \"$MM_DATA_DIR\" | awk \"{print \\\$3\\\":\\\"\\\$4}\"'" | tr -d '\r')
if [[ -z "$MM_OWNER" ]]; then
  MM_OWNER="0:0"
fi
echo "[+] Detected ownership: $MM_OWNER"

echo "[*] Stopping WeChat for user $TARGET_USER..."
$ADB_CMD shell "su -c 'am force-stop --user $TARGET_USER com.tencent.mm >/dev/null 2>&1 || true'"

echo "[*] Restoring moved credentials from $BACKUP_DIR..."
$ADB_CMD shell "su -c '
  D=\"$BACKUP_DIR\"
  DATA=\"$MM_DATA_DIR\"
  OWNER=\"$MM_OWNER\"

  if [ -f \"\$D/autoauth.cfg.moved\" ]; then
    mkdir -p \"\$DATA/files/kvcomm\" \"\$DATA/MicroMsg\"
    # Restore to MicroMsg and files/kvcomm locations
    cp \"\$D/autoauth.cfg.moved\" \"\$DATA/files/kvcomm/autoauth.cfg\" 2>/dev/null || true
    cp \"\$D/autoauth.cfg.moved\" \"\$DATA/MicroMsg/autoauth.cfg\" 2>/dev/null || true
    chown \"\$OWNER\" \"\$DATA/files/kvcomm/autoauth.cfg\" \"\$DATA/MicroMsg/autoauth.cfg\" 2>/dev/null || true
    chmod 600 \"\$DATA/files/kvcomm/autoauth.cfg\" \"\$DATA/MicroMsg/autoauth.cfg\" 2>/dev/null || true
    echo \"Restored autoauth.cfg\"
  fi

  if [ -f \"\$D/auth_hold_prefs.xml.moved\" ]; then
    mkdir -p \"\$DATA/shared_prefs\"
    cp \"\$D/auth_hold_prefs.xml.moved\" \"\$DATA/shared_prefs/auth_hold_prefs.xml\"
    chown \"\$OWNER\" \"\$DATA/shared_prefs/auth_hold_prefs.xml\"
    chmod 660 \"\$DATA/shared_prefs/auth_hold_prefs.xml\"
    echo \"Restored auth_hold_prefs.xml\"
  fi

  if [ -f \"\$D/auth_info_key_prefs.xml.moved\" ]; then
    mkdir -p \"\$DATA/shared_prefs\"
    cp \"\$D/auth_info_key_prefs.xml.moved\" \"\$DATA/shared_prefs/auth_info_key_prefs.xml\"
    chown \"\$OWNER\" \"\$DATA/shared_prefs/auth_info_key_prefs.xml\"
    chmod 660 \"\$DATA/shared_prefs/auth_info_key_prefs.xml\"
    echo \"Restored auth_info_key_prefs.xml\"
  fi
'"

echo "[*] Restarting WeChat LauncherUI..."
$ADB_CMD shell "su -c 'am start --user $TARGET_USER -n com.tencent.mm/.ui.LauncherUI >/dev/null 2>&1 || true'"

echo "=========================================================="
echo "[+] Rollback complete. Prior authentication state restored."
echo "=========================================================="
