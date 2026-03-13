#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Termux Auto Sync with Google Drive            ║
# ║  Copyright (c) 2025 Ahmed Awad                               ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ║  License : MIT                                               ║
# ╚══════════════════════════════════════════════════════════════╝
# watcher.sh — Main sync engine

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/scripts/logger.sh"
source "$SCRIPT_DIR/scripts/telegram.sh"

PID_FILE="$PROJECT_DIR/logs/watcher.pid"
PULL_PID_FILE="$PROJECT_DIR/logs/pull.pid"
UPLOADED_DB="$PROJECT_DIR/logs/uploaded.txt"
touch "$UPLOADED_DB"

# ── Upload a single file to Drive ─────────────────────────────
upload_file() {
  local FILE="$1"
  local DRIVE_DEST="$2"
  local BASE
  BASE="$(basename "$FILE")"

  [[ "$BASE" == .* || "$BASE" == *.tmp || "$BASE" == *.part || "$BASE" == *~ ]] && return
  [[ ! -f "$FILE" ]] && return

  if grep -qxF "$FILE" "$UPLOADED_DB" 2>/dev/null; then
    log SKIP "Already uploaded: $BASE"
    return
  fi

  sleep "$WRITE_WAIT"
  [[ ! -f "$FILE" ]] && return

  log UP "Uploading: $BASE --> $RCLONE_REMOTE:$DRIVE_DEST"
  notify_phone "Uploading: $BASE"

  if rclone copy "$FILE" "$RCLONE_REMOTE:$DRIVE_DEST" \
       --transfers=4 --checkers=8 \
       --log-file="$LOG_FILE" --log-level=ERROR \
       2>/dev/null; then
    echo "$FILE" >> "$UPLOADED_DB"
    log OK "Uploaded: $BASE"
    notify_phone "Done: $BASE"
    tg_send "upload" "✅ <b>Uploaded:</b> <code>${BASE}</code>\n📁 <code>${DRIVE_DEST}</code>"
  else
    log ERROR "Upload failed: $BASE"
    notify_phone "Upload failed: $BASE"
    tg_send "error" "❌ <b>Upload failed:</b> <code>${BASE}</code>"
  fi
}

# ── Pull a folder from Drive ───────────────────────────────────
pull_folder() {
  local DRIVE_SRC="$1"
  local LOCAL_DEST="$2"

  log DOWN "Pulling: $RCLONE_REMOTE:$DRIVE_SRC --> $LOCAL_DEST"
  notify_phone "Pulling from Drive: $DRIVE_SRC"
  tg_send "download" "⬇️ <b>Pull started:</b> <code>${DRIVE_SRC}</code>"
  mkdir -p "$LOCAL_DEST"

  if rclone copy "$RCLONE_REMOTE:$DRIVE_SRC" "$LOCAL_DEST" \
       --transfers=4 --checkers=8 \
       --log-file="$LOG_FILE" --log-level=ERROR \
       2>/dev/null; then
    log OK "Pull complete: $DRIVE_SRC"
    notify_phone "Pull done: $DRIVE_SRC"
    tg_send "download" "✅ <b>Pull complete:</b> <code>${DRIVE_SRC}</code>"
  else
    log ERROR "Pull failed: $DRIVE_SRC"
    tg_send "error" "❌ <b>Pull failed:</b> <code>${DRIVE_SRC}</code>"
  fi
}

# ── Auto-pull background loop ──────────────────────────────────
start_auto_pull() {
  while true; do
    sleep "$AUTO_PULL_INTERVAL"
    log INFO "Auto-pull cycle starting..."
    for ENTRY in "${SYNC_FOLDERS[@]}"; do
      IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
      if [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]]; then
        pull_folder "$DRIVE_PATH" "$LOCAL_PATH"
      fi
    done
  done
}

# ── Upload pre-existing files on first run ─────────────────────
upload_existing() {
  local LOCAL_PATH="$1"
  local DRIVE_PATH="$2"
  log INFO "Scanning existing files in: $LOCAL_PATH"
  find "$LOCAL_PATH" -maxdepth "$MAX_DEPTH" -type f 2>/dev/null | while read -r F; do
    upload_file "$F" "$DRIVE_PATH"
  done
}

# ── Startup ────────────────────────────────────────────────────
echo $$ > "$PID_FILE"

log INFO "════════════════════════════════════════"
log INFO " GDrive Sync v2.0 — Starting up"
log INFO " Author : Ahmed Awad (@ahmed-awad26)"
log INFO " Project: github.com/ahmed-awad26/gdrive-sync"
log INFO "════════════════════════════════════════"
tg_send "start" "🚀 <b>GDrive Sync started!</b>\nDevice: <code>$(hostname)</code>"

if ! command -v rclone &>/dev/null; then
  log ERROR "rclone not found! Run: pkg install rclone"; exit 1
fi
if ! command -v inotifywait &>/dev/null; then
  log ERROR "inotify-tools not found! Run: pkg install inotify-tools"; exit 1
fi

if ! rclone lsd "$RCLONE_REMOTE:" &>/dev/null; then
  log ERROR "Cannot reach $RCLONE_REMOTE — check rclone config"
  tg_send "error" "❌ Cannot connect to Drive! Check rclone config."
  exit 1
fi
log OK "Connected to $RCLONE_REMOTE"

# ── Dropbox bisync ─────────────────────────────────────────────
if [ "${DROPBOX_SYNC_ENABLED:-false}" = "true" ]; then
  log INFO "Dropbox-style bisync: $DROPBOX_LOCAL_ROOT <-> $RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT"
  BISYNC_FLAG=""
  [ ! -d "$HOME/.config/rclone/bisync" ] && BISYNC_FLAG="--resync" && log INFO "First bisync run — using --resync"
  rclone bisync "$DROPBOX_LOCAL_ROOT" "$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT" \
    $BISYNC_FLAG --create-empty-src-dirs --compare size,modtime,checksum \
    --resilient --force --log-file="$LOG_FILE" --log-level INFO 2>/dev/null &
  log OK "Dropbox-style bisync started in background"
fi

# ── Build watch list ───────────────────────────────────────────
WATCH_PATHS=()
for ENTRY in "${SYNC_FOLDERS[@]}"; do
  IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
  mkdir -p "$LOCAL_PATH" 2>/dev/null
  log INFO "Folder: [$DIRECTION] $LOCAL_PATH --> $RCLONE_REMOTE:$DRIVE_PATH"
  [ "$UPLOAD_EXISTING" = "true" ] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]] && \
    upload_existing "$LOCAL_PATH" "$DRIVE_PATH"
  [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]] && pull_folder "$DRIVE_PATH" "$LOCAL_PATH"
  [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]] && WATCH_PATHS+=("$LOCAL_PATH")
done

if [ "$AUTO_PULL_ENABLED" = "true" ]; then
  log INFO "Auto-pull enabled every ${AUTO_PULL_INTERVAL}s"
  start_auto_pull &
  echo $! > "$PULL_PID_FILE"
fi

log INFO "Watching ${#WATCH_PATHS[@]} folder(s) for new files..."

# ── Main inotify loop ──────────────────────────────────────────
inotifywait -m -r \
  --event close_write --event moved_to \
  --format '%w%f' \
  "${WATCH_PATHS[@]}" \
  2>/dev/null | while read -r FILEPATH; do

  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
    if [[ "$FILEPATH" == "$LOCAL_PATH"* ]] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
      REL="${FILEPATH#$LOCAL_PATH}"
      REL_DIR="$(dirname "$REL")"
      [ "$REL_DIR" = "." ] || [ -z "$REL_DIR" ] && DEST="$DRIVE_PATH" || DEST="$DRIVE_PATH/$REL_DIR"
      upload_file "$FILEPATH" "$DEST"
      break
    fi
  done

done
