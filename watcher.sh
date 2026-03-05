#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Termux Auto Sync with Google Drive        ║
# ║  Copyright (c) 2025 Ahmed Awad                           ║
# ║  GitHub : https://github.com/ahmed-awad26               ║
# ║  Project: https://github.com/ahmed-awad26/gdrive-sync   ║
# ║  License: MIT                                            ║
# ╚══════════════════════════════════════════════════════════╝

# ╔══════════════════════════════════════════════════════════════╗
# ║           🔄 GDrive Sync — المحرك الرئيسي                   ║
# ╚══════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/scripts/logger.sh"
source "$SCRIPT_DIR/scripts/telegram.sh"

PID_FILE="$PROJECT_DIR/logs/watcher.pid"
PULL_PID_FILE="$PROJECT_DIR/logs/pull.pid"
UPLOADED_DB="$PROJECT_DIR/logs/uploaded.txt"
touch "$UPLOADED_DB"

# ════════════════════════════════════════════
#  ⬆️  رفع ملف واحد إلى Drive
# ════════════════════════════════════════════
upload_file() {
  local FILE="$1"
  local DRIVE_DEST="$2"
  local BASE
  BASE="$(basename "$FILE")"

  # تخطي الملفات المخفية والمؤقتة
  [[ "$BASE" == .* || "$BASE" == *.tmp || "$BASE" == *.part || "$BASE" == *~ ]] && return
  [[ ! -f "$FILE" ]] && return

  # تخطي المرفوعة مسبقاً
  if grep -qxF "$FILE" "$UPLOADED_DB" 2>/dev/null; then
    log SKIP "محمّل مسبقاً: $BASE"
    return
  fi

  # انتظار اكتمال كتابة الملف
  sleep "$WRITE_WAIT"
  [[ ! -f "$FILE" ]] && return

  log UP "⬆️  رفع: $Base ──► $RCLONE_REMOTE:$DRIVE_DEST"
  notify_phone "⬆️ رفع: $Base"

  if rclone copy "$FILE" "$RCLONE_REMOTE:$DRIVE_DEST" \
       --transfers=4 --checkers=8 \
       --log-file="$LOG_FILE" --log-level=ERROR \
       2>/dev/null; then
    echo "$FILE" >> "$UPLOADED_DB"
    log OK "✅ تم رفع: $BASE"
    notify_phone "✅ تم: $BASE"
    tg_send "upload" "✅ <b>تم رفع:</b> <code>${BASE}</code>
📁 <code>${DRIVE_DEST}</code>"
  else
    log ERROR "❌ فشل رفع: $BASE"
    notify_phone "❌ فشل رفع: $BASE"
    tg_send "error" "❌ <b>فشل رفع:</b> <code>${BASE}</code>"
  fi
}

# ════════════════════════════════════════════
#  ⬇️  سحب فولدر من Drive → هاتف
# ════════════════════════════════════════════
pull_folder() {
  local DRIVE_SRC="$1"
  local LOCAL_DEST="$2"

  log DOWN "⬇️  سحب: $RCLONE_REMOTE:$DRIVE_SRC ──► $LOCAL_DEST"
  notify_phone "⬇️ سحب من Drive: $DRIVE_SRC"
  tg_send "download" "⬇️ <b>بدأ السحب من:</b> <code>${DRIVE_SRC}</code>"

  mkdir -p "$LOCAL_DEST"

  if rclone copy "$RCLONE_REMOTE:$DRIVE_SRC" "$LOCAL_DEST" \
       --transfers=4 --checkers=8 \
       --log-file="$LOG_FILE" --log-level=ERROR \
       2>/dev/null; then
    log OK "✅ تم السحب: $DRIVE_SRC"
    notify_phone "✅ تم السحب: $DRIVE_SRC"
    tg_send "download" "✅ <b>تم السحب:</b> <code>${DRIVE_SRC}</code>"
  else
    log ERROR "❌ فشل السحب: $DRIVE_SRC"
    tg_send "error" "❌ <b>فشل السحب:</b> <code>${DRIVE_SRC}</code>"
  fi
}

# ════════════════════════════════════════════
#  🔄 حلقة السحب التلقائي (background)
# ════════════════════════════════════════════
start_auto_pull() {
  while true; do
    sleep "$AUTO_PULL_INTERVAL"
    log INFO "🔄 جلسة سحب تلقائي..."
    for ENTRY in "${SYNC_FOLDERS[@]}"; do
      IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
      if [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]]; then
        pull_folder "$DRIVE_PATH" "$LOCAL_PATH"
      fi
    done
  done
}

# ════════════════════════════════════════════
#  📦 رفع الموجود مسبقاً (عند أول تشغيل)
# ════════════════════════════════════════════
upload_existing() {
  local LOCAL_PATH="$1"
  local DRIVE_PATH="$2"

  log INFO "📦 فحص الملفات الموجودة في: $LOCAL_PATH"
  find "$LOCAL_PATH" -maxdepth "$MAX_DEPTH" -type f 2>/dev/null | while read -r F; do
    upload_file "$F" "$DRIVE_PATH"
  done
}

# ════════════════════════════════════════════
#  🚀 بدء التشغيل الرئيسي
# ════════════════════════════════════════════
echo $$ > "$PID_FILE"

log INFO "════════════════════════════════"
log INFO "🚀 GDrive Sync بدأ التشغيل"
log INFO "════════════════════════════════"
tg_send "start" "🚀 <b>GDrive Sync شغّال!</b>
📱 الجهاز: <code>$(hostname)</code>"

# التحقق من المتطلبات
if ! command -v rclone &>/dev/null; then
  log ERROR "❌ rclone غير مثبت! شغّل: pkg install rclone"
  exit 1
fi
if ! command -v inotifywait &>/dev/null; then
  log ERROR "❌ inotify-tools غير مثبت! شغّل: pkg install inotify-tools"
  exit 1
fi

# التحقق من الاتصال
if ! rclone lsd "$RCLONE_REMOTE:" &>/dev/null; then
  log ERROR "❌ لا يوجد اتصال بـ $RCLONE_REMOTE — تحقق من rclone config"
  tg_send "error" "❌ <b>فشل الاتصال بـ Drive!</b>
تحقق من: rclone config"
  exit 1
fi

# بناء قائمة الفولدرات التي ترفع + تلك التي تسحب
WATCH_PATHS=()
for ENTRY in "${SYNC_FOLDERS[@]}"; do
  IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"

  mkdir -p "$LOCAL_PATH" 2>/dev/null
  log INFO "📁 $LOCAL_PATH  ──[$DIRECTION]──►  $RCLONE_REMOTE:$DRIVE_PATH"

  # رفع الموجود مسبقاً
  if [ "$UPLOAD_EXISTING" = "true" ] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
    upload_existing "$LOCAL_PATH" "$DRIVE_PATH"
  fi

  # سحب أولي عند start
  if [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]]; then
    pull_folder "$DRIVE_PATH" "$LOCAL_PATH"
  fi

  # إضافة للمراقبة لو في رفع
  if [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
    WATCH_PATHS+=("$LOCAL_PATH")
  fi
done

# تشغيل السحب التلقائي في الخلفية
if [ "$AUTO_PULL_ENABLED" = "true" ]; then
  log INFO "🔄 Auto-pull كل ${AUTO_PULL_INTERVAL}s"
  start_auto_pull &
  echo $! > "$PULL_PID_FILE"
fi

log INFO "👁️  بدأت المراقبة على ${#WATCH_PATHS[@]} فولدر..."

# ════════════════════════════════════════════
#  👁️  حلقة المراقبة الرئيسية
# ════════════════════════════════════════════
inotifywait -m -r \
  --event close_write \
  --event moved_to \
  --format '%w%f' \
  "${WATCH_PATHS[@]}" \
  2>/dev/null | while read -r FILEPATH; do

  # إيجاد الـ DRIVE_PATH المقابل لهذا الملف
  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
    if [[ "$FILEPATH" == "$LOCAL_PATH"* ]] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
      # حفظ الـ subpath
      REL="${FILEPATH#$LOCAL_PATH}"
      REL_DIR="$(dirname "$REL")"
      if [ "$REL_DIR" = "." ] || [ -z "$REL_DIR" ]; then
        DEST="$DRIVE_PATH"
      else
        DEST="$DRIVE_PATH/$REL_DIR"
      fi
      upload_file "$FILEPATH" "$DEST"
      break
    fi
  done

done

echo $$ > "$PID_FILE"

log INFO "════════════════════════════════════════"
log INFO " GDrive Sync v2.0 — Starting up"
log INFO " Author : Ahmed Awad (@ahmed-awad26)"
log INFO " Project: github.com/ahmed-awad26/gdrive-sync"
log INFO "════════════════════════════════════════"
tg_send "start" "<b>GDrive Sync started!</b>\nDevice: <code>$(hostname)</code>"

# Check dependencies
if ! command -v rclone &>/dev/null; then
  log ERROR "rclone not found! Run: pkg install rclone"
  exit 1
fi
if ! command -v inotifywait &>/dev/null; then
  log ERROR "inotify-tools not found! Run: pkg install inotify-tools"
  exit 1
fi

# Test Drive connection
if ! rclone lsd "$RCLONE_REMOTE:" &>/dev/null; then
  log ERROR "Cannot reach $RCLONE_REMOTE — check rclone config"
  tg_send "error" "Cannot connect to Drive! Check rclone config."
  exit 1
fi
log OK "Connected to $RCLONE_REMOTE"

# ── Full Dropbox-style sync (if enabled) ──────────────────────
if [ "${DROPBOX_SYNC_ENABLED:-false}" = "true" ]; then
  log INFO "Dropbox-style sync starting for root: $DROPBOX_LOCAL_ROOT <-> $RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT"
  rclone bisync \
    "$DROPBOX_LOCAL_ROOT" \
    "$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT" \
    --create-empty-src-dirs \
    --compare size,modtime,checksum \
    --resilient \
    --force \
    --log-file="$LOG_FILE" \
    --log-level INFO \
    2>/dev/null &
  log OK "Dropbox-style bisync started in background"
fi

WATCH_PATHS=()
for ENTRY in "${SYNC_FOLDERS[@]}"; do
  IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
  mkdir -p "$LOCAL_PATH" 2>/dev/null

  log INFO "Folder: [$DIRECTION] $LOCAL_PATH --> $RCLONE_REMOTE:$DRIVE_PATH"

  [ "$UPLOAD_EXISTING" = "true" ] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]] && \
    upload_existing "$LOCAL_PATH" "$DRIVE_PATH"

  [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]] && \
    pull_folder "$DRIVE_PATH" "$LOCAL_PATH"

  [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]] && \
    WATCH_PATHS+=("$LOCAL_PATH")
done

if [ "$AUTO_PULL_ENABLED" = "true" ]; then
  log INFO "Auto-pull enabled every ${AUTO_PULL_INTERVAL}s"
  start_auto_pull &
  echo $! > "$PULL_PID_FILE"
fi

log INFO "Watching ${#WATCH_PATHS[@]} folder(s) for new files..."

# ── Main inotify loop ─────────────────────────────────────────
inotifywait -m -r \
  --event close_write \
  --event moved_to \
  --format '%w%f' \
  "${WATCH_PATHS[@]}" \
  2>/dev/null | while read -r FILEPATH; do

  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
    if [[ "$FILEPATH" == "$LOCAL_PATH"* ]] && [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
      REL="${FILEPATH#$LOCAL_PATH}"
      REL_DIR="$(dirname "$REL")"
      if [ "$REL_DIR" = "." ] || [ -z "$REL_DIR" ]; then
        DEST="$DRIVE_PATH"
      else
        DEST="$DRIVE_PATH/$REL_DIR"
      fi
      upload_file "$FILEPATH" "$DEST"
      break
    fi
  done

done
