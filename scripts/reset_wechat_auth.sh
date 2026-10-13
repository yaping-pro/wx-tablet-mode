#!/usr/bin/env bash
#
# reset_wechat_auth.sh — Reset WeChat authentication state to clean blank slate.
#
# Implements SOP Step 4:
# 1. Inspects auth files for target user.
# 2. If all candidate auth files are already absent, exits idempotently without touching anything.
# 3. Stops WeChat for the target user.
# 4. Creates a timestamped backup directory under /data/adb/wx_stream/backup_auth_<TS>/
# 5. Moves existing auth files into backup PRESERVING THEIR FULL RELATIVE PATHS:
#      MicroMsg/autoauth.cfg              -> backup_auth_<TS>/MicroMsg/autoauth.cfg
#      files/kvcomm/autoauth.cfg          -> backup_auth_<TS>/files/kvcomm/autoauth.cfg
#      files/autoauth.cfg                 -> backup_auth_<TS>/files/autoauth.cfg
#      shared_prefs/auth_hold_prefs.xml   -> backup_auth_<TS>/shared_prefs/auth_hold_prefs.xml
#      shared_prefs/auth_info_key_prefs.xml -> backup_auth_<TS>/shared_prefs/auth_info_key_prefs.xml
# 6. NEVER creates basename collisions; leaves EnMicroMsg.db intact.
#
# Options:
#   --dry-run, -n    Print plan without modifying anything on device.
#
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRY_RUN=true
      ;;
    *)
      ;;
  esac
done

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/data/adb/wx_stream/backup_auth_${TIMESTAMP}"
MM_DATA_DIR="/data/user/${TARGET_USER}/com.tencent.mm"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=========================================================="
  echo "  wx-tablet-mode: Reset WeChat Auth [DRY-RUN MODE]        "
  echo "  Target User: $TARGET_USER                               "
  echo "  Source Dir:  $MM_DATA_DIR                               "
  echo "  Backup Plan: $BACKUP_DIR                                "
  echo "=========================================================="
  echo "[*] Probing authentication files on device (read-only)..."

  $ADB_CMD shell "su -c '
    FOUND=0
    for rel in \"MicroMsg/autoauth.cfg\" \"files/kvcomm/autoauth.cfg\" \"files/autoauth.cfg\" \"shared_prefs/auth_hold_prefs.xml\" \"shared_prefs/auth_info_key_prefs.xml\"; do
      target=\"$MM_DATA_DIR/\$rel\"
      if [ -f \"\$target\" ]; then
        sz=\$(stat -c \"%s\" \"\$target\" 2>/dev/null || wc -c < \"\$target\")
        echo \"[EXISTS] \$target (\$sz bytes)\"
        echo \"         -> Plan: Move to $BACKUP_DIR/\$rel\"
        FOUND=\$((FOUND + 1))
      else
        echo \"[ABSENT] \$target (clean / skipped)\"
      fi
    done
    echo \"--- Summary ---\"
    if [ \"\$FOUND\" -eq 0 ]; then
      echo \"All candidate auth files absent. System is already clean. Nothing would be modified.\"
    else
      echo \"Total files that would be moved: \$FOUND\"
      echo \"Action: Would execute am force-stop --user $TARGET_USER com.tencent.mm\"
      echo \"Action: Would mkdir -p $BACKUP_DIR (mode 0700)\"
      echo \"Action: Would move files preserving full relative subdirectories (no basename collision)\"
    fi
  '"
  echo "=========================================================="
  echo "[DRY-RUN] Finished. Device state was NOT modified."
  exit 0
fi

echo "=========================================================="
echo "  wx-tablet-mode: Reset WeChat Authentication State       "
echo "  Target User: $TARGET_USER                               "
echo "  Backup Target: $BACKUP_DIR                              "
echo "=========================================================="

echo "[*] Step 1: Probing active authentication files..."
EXISTING_COUNT=$($ADB_CMD shell "su -c '
  FOUND=0
  for rel in \"MicroMsg/autoauth.cfg\" \"files/kvcomm/autoauth.cfg\" \"files/autoauth.cfg\" \"shared_prefs/auth_hold_prefs.xml\" \"shared_prefs/auth_info_key_prefs.xml\"; do
    if [ -f \"$MM_DATA_DIR/\$rel\" ]; then
      FOUND=\$((FOUND + 1))
    fi
  done
  echo \$FOUND
'" | tr -d '\r')

if [[ "$EXISTING_COUNT" -eq 0 ]]; then
  echo "[+] All candidate authentication files are already absent in $MM_DATA_DIR."
  echo "    WeChat is already in a clean blank auth state. Idempotent skip (nothing to reset)."
  exit 0
fi

echo "[*] Step 2: Force-stopping WeChat for user $TARGET_USER..."
$ADB_CMD shell "su -c 'am force-stop --user $TARGET_USER com.tencent.mm >/dev/null 2>&1 || true'"

echo "[*] Step 3: Creating timestamped backup directory..."
$ADB_CMD shell "su -c 'mkdir -p \"$BACKUP_DIR\" && chmod 700 \"$BACKUP_DIR\"'"

echo "[*] Step 4: Moving authentication files preserving relative paths (blank slate)..."
$ADB_CMD shell "su -c '
  MOVED=0
  for rel in \"MicroMsg/autoauth.cfg\" \"files/kvcomm/autoauth.cfg\" \"files/autoauth.cfg\" \"shared_prefs/auth_hold_prefs.xml\" \"shared_prefs/auth_info_key_prefs.xml\"; do
    src=\"$MM_DATA_DIR/\$rel\"
    if [ -f \"\$src\" ]; then
      dest=\"$BACKUP_DIR/\$rel\"
      dest_dir=\"\${dest%/*}\"
      mkdir -p \"\$dest_dir\"
      mv \"\$src\" \"\$dest\"
      echo \"[+] Moved \$src -> \$dest\"
      MOVED=\$((MOVED + 1))
    fi
  done
  echo \"[+] Successfully moved \$MOVED authentication files.\"
'"

echo "[*] Step 5: Verifying clean slate..."
$ADB_CMD shell "su -c '
  echo \"--- Checking residual auth files in $MM_DATA_DIR ---\"
  for rel in \"MicroMsg/autoauth.cfg\" \"files/kvcomm/autoauth.cfg\" \"files/autoauth.cfg\" \"shared_prefs/auth_hold_prefs.xml\" \"shared_prefs/auth_info_key_prefs.xml\"; do
    target=\"$MM_DATA_DIR/\$rel\"
    if [ -f \"\$target\" ]; then
      echo \"[-] WARNING: \$rel is STILL PRESENT!\"
    else
      echo \"[✓] \$rel: ABSENT (clean)\"
    fi
  done
'"

echo "=========================================================="
echo "[+] Reset complete. WeChat is now in a clean blank auth state."
echo "    Original credentials safely saved in: $BACKUP_DIR"
echo "    To rollback if login fails, run: scripts/rollback_wechat_auth.sh $TIMESTAMP"
echo "=========================================================="
