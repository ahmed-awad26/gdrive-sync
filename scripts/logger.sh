#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Copyright (c) 2025 Ahmed Awad                 ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
# logger.sh — Logging & phone notification helpers

LOG_FILE="${PROJECT_DIR:-$HOME/gdrive-sync}/logs/watcher.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
  local LEVEL="$1"; shift
  local MSG="$*"

  local COLOR=""
  case "$LEVEL" in
    INFO)  COLOR="\033[0;36m"  ;;
    OK)    COLOR="\033[0;32m"  ;;
    WARN)  COLOR="\033[1;33m"  ;;
    ERROR) COLOR="\033[0;31m"  ;;
    UP)    COLOR="\033[0;35m"  ;;
    DOWN)  COLOR="\033[0;34m"  ;;
    SKIP)  COLOR="\033[2;37m"  ;;
  esac
  local NC="\033[0m"
  local TIMESTAMP
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  local LINE="[$TIMESTAMP] [$LEVEL] $MSG"

  echo -e "${COLOR}${LINE}${NC}"
  echo "$LINE" >> "$LOG_FILE"

  # Trim log if too large
  local COUNT
  COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$COUNT" -gt "${LOG_MAX_LINES:-1000}" ]; then
    local KEEP=$(( ${LOG_MAX_LINES:-1000} / 2 ))
    tail -"$KEEP" "$LOG_FILE" > "${LOG_FILE}.tmp"
    mv "${LOG_FILE}.tmp" "$LOG_FILE"
  fi
}

notify_phone() {
  command -v termux-notification &>/dev/null || return
  termux-notification \
    --title "GDrive Sync" \
    --content "$1" \
    --id gdrive_sync \
    --sound 2>/dev/null &
}
