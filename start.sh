#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Copyright (c) 2025 Ahmed Awad                 ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
PID_FILE="$PROJECT_DIR/logs/watcher.pid"
mkdir -p "$PROJECT_DIR/logs"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "[WARN] Watcher already running (PID: $(cat "$PID_FILE"))"
  exit 0
fi

nohup bash "$SCRIPT_DIR/watcher.sh" >> "$PROJECT_DIR/logs/watcher.log" 2>&1 &
sleep 1

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "[OK] GDrive Sync started! PID: $(cat "$PID_FILE")"
  echo "     Log: tail -f $PROJECT_DIR/logs/watcher.log"
else
  echo "[ERR] Startup failed — check the log:"
  tail -10 "$PROJECT_DIR/logs/watcher.log" 2>/dev/null
  exit 1
fi
