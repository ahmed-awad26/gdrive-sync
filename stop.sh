#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Copyright (c) 2025 Ahmed Awad                 ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
PID_FILE="$PROJECT_DIR/logs/watcher.pid"
PULL_PID="$PROJECT_DIR/logs/pull.pid"

STOPPED=false
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
  echo "[OK] Watcher stopped"
  STOPPED=true
fi
if [ -f "$PULL_PID" ] && kill -0 "$(cat "$PULL_PID")" 2>/dev/null; then
  kill "$(cat "$PULL_PID")" && rm -f "$PULL_PID"
  echo "[OK] Auto-pull stopped"
fi
pkill -f "inotifywait.*gdrive-sync" 2>/dev/null
[ "$STOPPED" = false ] && echo "[WARN] Watcher was not running"
