#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Copyright (c) 2025 Ahmed Awad                 ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
PID_FILE="$PROJECT_DIR/logs/watcher.pid"
LOG="$PROJECT_DIR/logs/watcher.log"
UPLOADED="$PROJECT_DIR/logs/uploaded.txt"

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         GDrive Sync — STATUS             ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "  Status      : RUNNING (PID: $(cat "$PID_FILE"))"
else
  echo "  Status      : STOPPED"
fi

DRIVE_STATUS="ERR"
rclone lsd "$RCLONE_REMOTE:" &>/dev/null && DRIVE_STATUS="OK"

echo "  Remote      : $RCLONE_REMOTE [$DRIVE_STATUS]"
echo "  Telegram    : $TELEGRAM_ENABLED"
echo "  Dropbox sync: $DROPBOX_SYNC_ENABLED"
echo "  Folders     : ${#SYNC_FOLDERS[@]} tracked"
echo "  Uploaded    : $(wc -l < "$UPLOADED" 2>/dev/null || echo 0) files"
echo ""
echo "  -- Folders -----------------------------------------------"
for ENTRY in "${SYNC_FOLDERS[@]}"; do
  IFS='|' read -r L D DIR <<< "$ENTRY"
  printf "  [%s] %-35s --> %s\n" "$DIR" "$(basename "$L")" "$RCLONE_REMOTE:$D"
done
echo ""
echo "  -- Last 10 log lines -------------------------------------"
tail -10 "$LOG" 2>/dev/null || echo "  No log yet"
echo "  ══════════════════════════════════════════════════════════"
