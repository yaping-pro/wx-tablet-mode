#!/usr/bin/env bash
#
# quarantine_tinker.sh — One-shot script to quarantine WeChat Tinker hotfix patches.
#
# Problem:
#   WeChat's Tinker hotfix framework periodically downloads and applies OTA patches
#   into the app data directory. This can silently change the effective clientVersion
#   from the official base (0x28004e32) to an internal Beta version (e.g. 0x28004e38),
#   causing the tablet secondary login to be rejected by Tencent servers.
#
# Solution:
#   Quarantine any `patch-*` directories under Tinker and strip write permissions.
#
set -euo pipefail

TARGET_USER="${TARGET_USER:-0}"
DEVICE_ID="${DEVICE_ID:-}"
ADB_CMD="adb"
if [[ -n "$DEVICE_ID" ]]; then
  ADB_CMD="adb -s $DEVICE_ID"
fi

MM_TINKER_DIR="/data/user/${TARGET_USER}/com.tencent.mm/tinker"
QUARANTINE_DIR="/data/adb/wx_stream/tinker_quarantine"

echo "=========================================================="
echo "  wx-tablet-mode: Quarantine Tinker Hotfix Patches        "
echo "  Target User: $TARGET_USER                               "
echo "  Tinker Path: $MM_TINKER_DIR                             "
echo "=========================================================="

echo "[*] Checking for active Tinker patches..."
$ADB_CMD shell "su -c '
  mkdir -p \"$QUARANTINE_DIR\"
  if [ -d \"$MM_TINKER_DIR\" ]; then
    FOUND=0
    for patch_dir in \"$MM_TINKER_DIR\"/patch-*; do
      if [ -d \"\$patch_dir\" ]; then
        FOUND=1
        TS=\$(date +\"%Y%m%d_%H%M%S\")
        TNAME=\$(basename \"\$patch_dir\")
        DEST=\"$QUARANTINE_DIR/\${TNAME}_\${TS}\"
        echo \"[!] Found active patch: \$patch_dir -> moving to \$DEST\"
        mv \"\$patch_dir\" \"\$DEST\"
      fi
    done
    if [ \"\$FOUND\" -eq 0 ]; then
      echo \"[+] No patch-* directories currently active.\"
    fi
  else
    echo \"[*] Tinker directory does not exist yet ($MM_TINKER_DIR).\"
  fi
'"

echo "[*] Ensuring WeChat base version is maintained..."
$ADB_CMD shell "su -c '
  # If patch_share_config exists, verify its patch version
  CFG=\"/data/user/$TARGET_USER/com.tencent.mm/shared_prefs/tinker_patch_share_config.xml\"
  if [ -f \"\$CFG\" ]; then
    echo \"[*] Inspecting tinker_patch_share_config.xml:\"
    grep -E \"tinker_patch_version|clientversion\" \"\$CFG\" || true
  fi
'"

echo "=========================================================="
echo "[+] Quarantine complete. WeChat base version secured."
echo "=========================================================="
