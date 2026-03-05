#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Copyright (c) 2025 Ahmed Awad                 ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
# telegram.sh — Send Telegram notifications

tg_send() {
  local TYPE="$1"
  local MSG="$2"

  [ "${TELEGRAM_ENABLED}" != "true" ] && return
  [ -z "${TELEGRAM_BOT_TOKEN}" ]      && return
  [ -z "${TELEGRAM_CHAT_ID}" ]        && return
  echo "${TELEGRAM_EVENTS}" | grep -qw "$TYPE" || return

  local ICON
  case "$TYPE" in
    upload)   ICON="☁️  UPLOAD"   ;;
    download) ICON="📥 DOWNLOAD" ;;
    error)    ICON="❌ ERROR"    ;;
    start)    ICON="🚀 STARTED"  ;;
    stop)     ICON="🛑 STOPPED"  ;;
    *)        ICON="ℹ️  INFO"    ;;
  esac

  local TEXT="${ICON}
${MSG}
$(date '+%Y-%m-%d %H:%M:%S')"

  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${TEXT}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1 &
}

tg_test() {
  if [ -z "${TELEGRAM_BOT_TOKEN}" ] || [ -z "${TELEGRAM_CHAT_ID}" ]; then
    echo "[ERROR] BOT_TOKEN or CHAT_ID is empty in config.sh"
    return 1
  fi

  local RES
  RES=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null)

  if echo "$RES" | grep -q '"ok":true'; then
    local NAME
    NAME=$(echo "$RES" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
    echo "[OK] Connected! Bot: @${NAME}"
    tg_send "start" "Connection test successful!\nBot: @${NAME}"
    echo "[OK] Test message sent to Telegram"
  else
    echo "[ERROR] Connection failed — check TELEGRAM_BOT_TOKEN"
    return 1
  fi
}
