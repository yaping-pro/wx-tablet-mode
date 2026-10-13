#!/usr/bin/env bash
#
# rollback_wechat_auth.sh — Restore previous WeChat authentication state from backup.
#
# Usage:
#   bash scripts/rollback_wechat_auth.sh [--dry-run] [TIMESTAMP]
#
# If TIMESTAMP is not specified, uses the latest backup in /data/adb/wx_stream/backup_auth_*.
# Restores each file EXACTLY to its original absolute path under the target user's app directory.
#
set -euo pipefail

DRY_RUN=false
TS=""

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)
      DRY_RUN=true
      ;;
    *)
      if [[ -z "$TS" ]]; then
        TS="$arg"
      fi
      ;;
  esac
done

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=========================================================="
  echo "  wx-tablet-mode: Rollback WeChat Auth [DRY-RUN MODE]     "
  echo "  Target User: $TARGET_USER                               "
  echo "=========================================================="
fi

if [[ -z "$TS" ]]; then
  echo "[*] Discovering latest backup directory on device..."
  LATEST_BACKUP=$($ADB_CMD shell "su -c 'ls -td /data/adb/wx_stream/backup_auth_* 2>/dev/null | head -1'" | tr -d '\r')
  if [[ -z "$LATEST_BACKUP" ]]; then
    echo "[-] ERROR: No auth backups found under /data/adb/wx_stream/." >&2
    exit 1
  fi
  BACKUP_DIR="$LATEST_BACKUP"
else
  if [[ "$TS" == /* ]]; then
    BACKUP_DIR="$TS"
  else
    BACKUP_DIR="/data/adb/wx_stream/backup_auth_${TS}"
  fi
fi

echo "[*] Backup source: $BACKUP_DIR"

# Verify backup dir exists on device
BACKUP_EXISTS=$($ADB_CMD shell "su -c 'test -d \"$BACKUP_DIR\" && echo ok || true'" | tr -d '\r')
if [[ "$BACKUP_EXISTS" != "ok" ]]; then
  echo "[-] ERROR: Backup directory does not exist: $BACKUP_DIR" >&2
  exit 1
fi

MM_DATA_DIR="/data/user/${TARGET_USER}/com.tencent.mm"

# Dynamically discover UID/GID of the WeChat data directory
echo "[*] Detecting ownership for $MM_DATA_DIR..."
MM_OWNER=$($ADB_CMD shell "su -c 'stat -c \"%u:%g\" \"$MM_DATA_DIR\" 2>/dev/null || ls -ld \"$MM_DATA_DIR\" | awk \"{print \\\$3\\\":\\\"\\\$4}\"'" | tr -d '\r')
if [[ -z "$MM_OWNER" ]]; then
  MM_OWNER="0:0"
fi
echo "[+] Detected ownership: $MM_OWNER"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[*] Inspecting files in backup directory (read-only)..."
  $ADB_CMD shell "su -c '
    FILES=\$(find \"$BACKUP_DIR\" -type f 2>/dev/null || true)
    if [ -z \"\$FILES\" ]; then
      echo \"[-] No files found inside $BACKUP_DIR.\"
      exit 0
    fi
    echo \"Files to restore:\"
    for f in \$FILES; do
      rel=\"\${f#$BACKUP_DIR/}\"
      # Handle legacy moved file flat names if encountered
      if [ \"\$rel\" = \"autoauth.cfg.moved\" ] || [ \"\$rel\" = \"autoauth.cfg.bak\" ]; then
        dest=\"$MM_DATA_DIR/MicroMsg/autoauth.cfg\"
        mode=\"600\"
      elif [ \"\$rel\" = \"auth_hold_prefs.xml.moved\" ]; then
        dest=\"$MM_DATA_DIR/shared_prefs/auth_hold_prefs.xml\"
        mode=\"660\"
      elif [ \"\$rel\" = \"auth_info_key_prefs.xml.moved\" ]; then
        dest=\"$MM_DATA_DIR/shared_prefs/auth_info_key_prefs.xml\"
        mode=\"660\"
      else
        dest=\"$MM_DATA_DIR/\$rel\"
        case \"\$rel\" in
          *.xml) mode=\"660\" ;;
          *)     mode=\"600\" ;;
        esac
      fi
      sz=\$(stat -c \"%s\" \"\$f\" 2>/dev/null || wc -c < \"\$f\")
      echo \"[PLAN] Restore: \$f (\$sz bytes)\"
      echo \"       -> Dest:   \$dest (owner $MM_OWNER, mode \$mode)\"
    done
    echo \"--- Summary ---\"
    echo \"Action: Would force-stop com.tencent.mm for user $TARGET_USER\"
    echo \"Action: Would copy files to exact original destination paths\"
    echo \"Action: Would fix ownership to $MM_OWNER and permissions\"
    echo \"Action: Would restart LauncherUI for user $TARGET_USER\"
  '"
  echo "=========================================================="
  echo "[DRY-RUN] Finished. Device state was NOT modified."
  exit 0
fi

echo "=========================================================="
echo "  wx-tablet-mode: Rollback WeChat Authentication State    "
echo "  Target User: $TARGET_USER                               "
echo "  Backup Source: $BACKUP_DIR                              "
echo "=========================================================="

echo "[*] Step 1: Stopping WeChat for user $TARGET_USER..."
$ADB_CMD shell "su -c 'am force-stop --user $TARGET_USER com.tencent.mm >/dev/null 2>&1 || true'"

echo "[*] Step 2: Restoring credentials to exact original paths..."
$ADB_CMD shell "su -c '
  BACKUP=\"$BACKUP_DIR\"
  DATA=\"$MM_DATA_DIR\"
  OWNER=\"$MM_OWNER\"

  FILES=\$(find \"\$BACKUP\" -type f 2>/dev/null || true)
  if [ -z \"\$FILES\" ]; then
    echo \"[-] ERROR: No files found in backup directory \$BACKUP\"
    exit 1
  fi

  RESTORED=0
  for f in \$FILES; do
    rel=\"\${f#\$BACKUP/}\"
    if [ \"\$rel\" = \"autoauth.cfg.moved\" ] || [ \"\$rel\" = \"autoauth.cfg.bak\" ]; then
      dest=\"\$DATA/MicroMsg/autoauth.cfg\"
      mode=\"600\"
    elif [ \"\$rel\" = \"auth_hold_prefs.xml.moved\" ]; then
      dest=\"\$DATA/shared_prefs/auth_hold_prefs.xml\"
      mode=\"660\"
    elif [ \"\$rel\" = \"auth_info_key_prefs.xml.moved\" ]; then
      dest=\"\$DATA/shared_prefs/auth_info_key_prefs.xml\"
      mode=\"660\"
    else
      dest=\"\$DATA/\$rel\"
      case \"\$rel\" in
        *.xml) mode=\"660\" ;;
        *)     mode=\"600\" ;;
      esac
    fi

    dest_dir=\"\${dest%/*}\"
    mkdir -p \"\$dest_dir\"
    cp -f \"\$f\" \"\$dest\"
    chown \"\$OWNER\" \"\$dest\"
    chmod \"\$mode\" \"\$dest\"
    echo \"[+] Restored: \$rel -> \$dest (mode \$mode)\"
    RESTORED=\$((RESTORED + 1))
  done

  echo \"[+] Restored \$RESTORED files successfully.\"
'"

echo "[*] Step 3: Restarting WeChat LauncherUI..."
$ADB_CMD shell "su -c 'am start --user $TARGET_USER -n com.tencent.mm/.ui.LauncherUI >/dev/null 2>&1 || true'"

echo "=========================================================="
echo "[+] Rollback complete. Prior authentication state restored."
echo "=========================================================="
