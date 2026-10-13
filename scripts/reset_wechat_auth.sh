#!/usr/bin/env bash
#
# reset_wechat_auth.sh — Reset WeChat authentication state to clean blank slate.
#
# Implements SOP Step 4:
# 1. Stops WeChat for the target user.
# 2. Creates a timestamped backup directory under /data/adb/wx_stream/backup_auth_<TS>/
# 3. MOVES autoauth.cfg and auth_hold_prefs.xml into backup, rendering them ABSENT
#    in the original app directory.
# 4. NEVER copies old credentials back; leaves EnMicroMsg.db intact.
#
set -euo pipefail

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/data/adb/wx_stream/backup_auth_${TIMESTAMP}"

# In Android multi-user environments:
# User 0: /data/user/0/com.tencent.mm or /data/data/com.tencent.mm
# User N: /data/user/N/com.tencent.mm
MM_DATA_DIR="/data/user/${TARGET_USER}/com.tencent.mm"

echo "=========================================================="
echo "  wx-tablet-mode: Reset WeChat Authentication State       "
echo "  Target User: $TARGET_USER                               "
echo "  Backup Target: $BACKUP_DIR                              "
echo "=========================================================="

echo "[*] Step 1: Force-stopping WeChat for user $TARGET_USER..."
$ADB_CMD shell "su -c 'am force-stop --user $TARGET_USER com.tencent.mm >/dev/null 2>&1 || true'"

echo "[*] Step 2: Creating backup directory..."
$ADB_CMD shell "su -c 'mkdir -p \"$BACKUP_DIR\" && chmod 700 \"$BACKUP_DIR\"'"

echo "[*] Step 3: Moving authentication files to backup (blank slate)..."
# Move autoauth.cfg if exists
$ADB_CMD shell "su -c '
  for f in \"$MM_DATA_DIR/files/kvcomm/autoauth.cfg\" \"$MM_DATA_DIR/files/autoauth.cfg\"; do
    if [ -f \"\$f\" ]; then
      mv \"\$f\" \"$BACKUP_DIR/\$(basename \$f).moved\"
      echo \"Moved \$f -> $BACKUP_DIR\"
    fi
  done
  for f in \"$MM_DATA_DIR/shared_prefs/auth_hold_prefs.xml\" \"$MM_DATA_DIR/shared_prefs/auth_info_key_prefs.xml\"; do
    if [ -f \"\$f\" ]; then
      mv \"\$f\" \"$BACKUP_DIR/\$(basename \$f).moved\"
      echo \"Moved \$f -> $BACKUP_DIR\"
    fi
  done
'"

echo "[*] Step 4: Verifying clean slate..."
$ADB_CMD shell "su -c '
  echo \"--- Checking residual auth files in $MM_DATA_DIR ---\"
  ls -l \"$MM_DATA_DIR/files/kvcomm/autoauth.cfg\" 2>/dev/null || echo \"autoauth.cfg: ABSENT (clean)\"
  ls -l \"$MM_DATA_DIR/shared_prefs/auth_hold_prefs.xml\" 2>/dev/null || echo \"auth_hold_prefs.xml: ABSENT (clean)\"
'"

echo "=========================================================="
echo "[+] Reset complete. WeChat is now in a clean blank auth state."
echo "    Original credentials safely saved in: $BACKUP_DIR"
echo "    To rollback if login fails, run: scripts/rollback_wechat_auth.sh"
echo "=========================================================="
