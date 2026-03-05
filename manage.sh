#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Termux Auto Sync with Google Drive            ║
# ║  Copyright (c) 2025 Ahmed Awad                               ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ║  License : MIT                                               ║
# ╚══════════════════════════════════════════════════════════════╝
# manage.sh — Interactive management panel (English only)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Colors
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' B='\033[1m'    D='\033[2m'   N='\033[0m'
LINE="${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

hdr() {
  clear 2>/dev/null || printf '\033[2J\033[H'
  echo -e "${C}${B}"
  echo "   ╔══════════════════════════════════════════════╗"
  echo "   ║                                              ║"
  echo "   ║   ██████╗ ██████╗ ██╗██╗   ██╗███████╗      ║"
  echo "   ║   ██╔══██╗██╔══██╗██║██║   ██║██╔════╝      ║"
  echo "   ║   ██║  ██║██████╔╝██║██║   ██║█████╗        ║"
  echo "   ║   ██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝        ║"
  echo "   ║   ██████╔╝██║  ██║██║ ╚████╔╝ ███████╗      ║"
  echo "   ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝      ║"
  echo "   ║                  GDrive Sync                ║"
  echo "   ║          by Ahmed Awad @ahmed-awad26        ║"
  echo "   ╚══════════════════════════════════════════════╝"
  echo -e "${N}"
}

pause() { echo ""; read -rp "   Press Enter to continue..." _; }

watcher_status() {
  if [ -f "$PROJECT_DIR/logs/watcher.pid" ] && \
     kill -0 "$(cat "$PROJECT_DIR/logs/watcher.pid")" 2>/dev/null; then
    echo -e "  ${G}● RUNNING${N} (PID: $(cat "$PROJECT_DIR/logs/watcher.pid"))"
  else
    echo -e "  ${R}○ STOPPED${N}"
  fi
}

# ── Folders menu ──────────────────────────────────────────────
menu_folders() {
  while true; do
    hdr
    source "$SCRIPT_DIR/config.sh"
    echo -e "${B}   SYNC FOLDERS${N}\n"
    echo -e "$LINE"

    local i=1
    for ENTRY in "${SYNC_FOLDERS[@]}"; do
      IFS='|' read -r L D DIR <<< "$ENTRY"
      local ARROW
      case "$DIR" in
        up)   ARROW="${G}-->${N}" ;;
        down) ARROW="${C}<--${N}" ;;
        both) ARROW="${Y}<->${N}" ;;
      esac
      printf "   ${Y}[%d]${N}  %s\n" "$i" "$(basename "$L")"
      echo -e "         $ARROW  $RCLONE_REMOTE:$D  ${D}($DIR)${N}"
      echo ""
      ((i++))
    done

    echo -e "$LINE"
    echo -e "   ${G}[A]${N}  Add new folder"
    echo -e "   ${R}[D]${N}  Remove a folder"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      [Aa])
        echo ""
        read -rp "   Local path (e.g. $HOME/storage/downloads): " NEW_LOCAL
        read -rp "   Drive path (e.g. GDriveSync/Downloads):    " NEW_DRIVE
        echo -e "   Direction: ${Y}[1]${N} up  ${Y}[2]${N} down  ${Y}[3]${N} both"
        read -rp "   Choose [1-3]: " DIR_CH
        case "$DIR_CH" in
          1) NEW_DIR="up"   ;;
          2) NEW_DIR="down" ;;
          3) NEW_DIR="both" ;;
          *) echo "${R}Invalid choice${N}"; pause; continue ;;
        esac
        local NEW_ENTRY="  \"$NEW_LOCAL|$NEW_DRIVE|$NEW_DIR\""
        sed -i "/^SYNC_FOLDERS=(/,/^\)/{/^\)/i\\$NEW_ENTRY
}" "$SCRIPT_DIR/config.sh"
        echo -e "\n  ${G}[OK] Folder added!${N}"
        source "$SCRIPT_DIR/config.sh"
        pause ;;
      [Dd])
        echo ""
        read -rp "   Folder number to remove: " DEL_NUM
        if [[ "$DEL_NUM" =~ ^[0-9]+$ ]] && \
           [ "$DEL_NUM" -ge 1 ] && [ "$DEL_NUM" -le "${#SYNC_FOLDERS[@]}" ]; then
          local DEL_PATH
          IFS='|' read -r DEL_PATH _ _ <<< "${SYNC_FOLDERS[$((DEL_NUM-1))]}"
          python3 -c "
path = open('$SCRIPT_DIR/config.sh').read()
lines = [l for l in path.splitlines() if '$DEL_PATH' not in l or l.strip().startswith('#')]
open('$SCRIPT_DIR/config.sh','w').write('\n'.join(lines)+'\n')
" 2>/dev/null && echo -e "\n  ${G}[OK] Removed!${N}" || echo -e "\n  ${R}[ERR] Edit config.sh manually${N}"
          source "$SCRIPT_DIR/config.sh"
        else
          echo -e "  ${R}[ERR] Invalid number${N}"
        fi
        pause ;;
      0) break ;;
    esac
  done
}

# ── Dropbox-style sync menu ───────────────────────────────────
menu_dropbox() {
  while true; do
    hdr
    source "$SCRIPT_DIR/config.sh"
    echo -e "${B}   DROPBOX-STYLE SYNC (bisync)${N}\n"
    echo -e "$LINE"
    echo -e "   ${D}Keeps a local folder perfectly mirrored with Drive.${N}"
    echo -e "   ${D}Changes on either side are merged automatically.${N}\n"
    echo -e "   Enabled      : $([ "$DROPBOX_SYNC_ENABLED" = "true" ] && echo "${G}YES${N}" || echo "${R}NO${N}")"
    echo -e "   Local root   : ${C}$DROPBOX_LOCAL_ROOT${N}"
    echo -e "   Drive root   : ${C}$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT${N}"
    echo -e "   Interval     : ${C}${DROPBOX_SYNC_INTERVAL}s${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Toggle on / off"
    echo -e "   ${Y}[2]${N}  Change local root folder"
    echo -e "   ${Y}[3]${N}  Change Drive root folder"
    echo -e "   ${Y}[4]${N}  Change sync interval"
    echo -e "   ${Y}[5]${N}  Run bisync NOW (manual)"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1)
        local NEW_VAL
        [ "$DROPBOX_SYNC_ENABLED" = "true" ] && NEW_VAL="false" || NEW_VAL="true"
        sed -i "s/^DROPBOX_SYNC_ENABLED=.*/DROPBOX_SYNC_ENABLED=\"$NEW_VAL\"/" "$SCRIPT_DIR/config.sh"
        echo -e "\n  ${G}[OK] Dropbox sync: $NEW_VAL${N}"
        source "$SCRIPT_DIR/config.sh"; pause ;;
      2)
        read -rp "   New local root path: " V
        sed -i "s|^DROPBOX_LOCAL_ROOT=.*|DROPBOX_LOCAL_ROOT=\"$V\"|" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      3)
        read -rp "   New Drive root folder name: " V
        sed -i "s/^DROPBOX_DRIVE_ROOT=.*/DROPBOX_DRIVE_ROOT=\"$V\"/" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      4)
        read -rp "   Interval in seconds: " V
        sed -i "s/^DROPBOX_SYNC_INTERVAL=.*/DROPBOX_SYNC_INTERVAL=$V/" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      5)
        echo ""
        source "$SCRIPT_DIR/config.sh"
        mkdir -p "$DROPBOX_LOCAL_ROOT"
        echo -e "  ${C}Running bisync: $DROPBOX_LOCAL_ROOT <-> $RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT${N}"

        # First-time setup: use --resync if no prior state
        BISYNC_FLAG=""
        BISYNC_STATE="$HOME/.config/rclone/bisync"
        if [ ! -d "$BISYNC_STATE" ]; then
          echo -e "  ${Y}First run detected — using --resync (safe initial sync)${N}"
          BISYNC_FLAG="--resync"
        fi

        rclone bisync \
          "$DROPBOX_LOCAL_ROOT" \
          "$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT" \
          $BISYNC_FLAG \
          --create-empty-src-dirs \
          --compare size,modtime,checksum \
          --resilient \
          --force \
          --progress \
          2>&1 | tail -20
        echo -e "\n  ${G}[OK] Bisync complete!${N}"; pause ;;
      0) break ;;
    esac
  done
}

# ── Telegram menu ─────────────────────────────────────────────
menu_telegram() {
  while true; do
    hdr
    source "$SCRIPT_DIR/config.sh"
    echo -e "${B}   TELEGRAM NOTIFICATIONS${N}\n"
    echo -e "$LINE"
    echo -e "   Enabled  : $([ "$TELEGRAM_ENABLED" = "true" ] && echo "${G}YES${N}" || echo "${R}NO${N}")"
    echo -e "   Token    : ${D}${TELEGRAM_BOT_TOKEN:-<empty>}${N}"
    echo -e "   Chat ID  : ${D}${TELEGRAM_CHAT_ID:-<empty>}${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Toggle on / off"
    echo -e "   ${Y}[2]${N}  Set BOT_TOKEN"
    echo -e "   ${Y}[3]${N}  Set CHAT_ID"
    echo -e "   ${Y}[4]${N}  Test connection"
    echo -e "   ${Y}[5]${N}  Setup guide"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1)
        local NEW_VAL; [ "$TELEGRAM_ENABLED" = "true" ] && NEW_VAL="false" || NEW_VAL="true"
        sed -i "s/^TELEGRAM_ENABLED=.*/TELEGRAM_ENABLED=\"$NEW_VAL\"/" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Telegram: $NEW_VAL${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      2)
        read -rp "   Enter BOT_TOKEN: " V
        sed -i "s/^TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=\"$V\"/" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      3)
        read -rp "   Enter CHAT_ID: " V
        sed -i "s/^TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=\"$V\"/" "$SCRIPT_DIR/config.sh"
        echo -e "  ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      4)
        echo ""
        source "$SCRIPT_DIR/scripts/telegram.sh"
        tg_test; pause ;;
      5)
        hdr
        echo -e "${B}   TELEGRAM SETUP GUIDE${N}\n"
        echo -e "$LINE"
        echo -e "   ${Y}Step 1 — Create a Bot:${N}"
        echo -e "   • Open Telegram -> search ${C}@BotFather${N}"
        echo -e "   • Send: /newbot"
        echo -e "   • Choose a name for your bot"
        echo -e "   • Copy the ${G}Token${N} it gives you\n"
        echo -e "   ${Y}Step 2 — Get your Chat ID:${N}"
        echo -e "   • Search ${C}@userinfobot${N} on Telegram"
        echo -e "   • Send any message"
        echo -e "   • Copy the ${G}Id${N} it shows you\n"
        echo -e "   ${Y}Step 3 — Activate your Bot:${N}"
        echo -e "   • Search your bot by name in Telegram"
        echo -e "   • Press ${G}Start${N} or send /start\n"
        echo -e "   ${Y}Step 4:${N}"
        echo -e "   • Enter Token in option [2]"
        echo -e "   • Enter Chat ID in option [3]"
        echo -e "   • Enable in option [1]"
        echo -e "   • Test with option [4]"
        pause ;;
      0) break ;;
    esac
  done
}

# ── rclone / Drive menu ───────────────────────────────────────
menu_rclone() {
  while true; do
    hdr
    source "$SCRIPT_DIR/config.sh"
    echo -e "${B}   GOOGLE DRIVE / RCLONE${N}\n"
    echo -e "$LINE"
    echo -e "   Remote   : ${C}$RCLONE_REMOTE${N}"
    local STATUS
    rclone lsd "$RCLONE_REMOTE:" &>/dev/null && STATUS="${G}Connected${N}" || STATUS="${R}Not connected${N}"
    echo -e "   Status   : $STATUS\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Setup Google Drive (rclone config)"
    echo -e "   ${Y}[2]${N}  Test connection"
    echo -e "   ${Y}[3]${N}  Browse Drive folders"
    echo -e "   ${Y}[4]${N}  Change remote name"
    echo -e "   ${Y}[5]${N}  Step-by-step setup guide"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) echo -e "\n  ${Y}Tip: When asked 'Use web browser?' choose [n] then open the link in Chrome${N}\n"
         read -rp "   Press Enter to open rclone config..."
         rclone config; pause ;;
      2) echo ""
         rclone lsd "$RCLONE_REMOTE:" &>/dev/null && \
           echo -e "  ${G}[OK] Connected to $RCLONE_REMOTE!${N}" || \
           echo -e "  ${R}[ERR] Connection failed — run rclone config${N}"
         pause ;;
      3) echo -e "\n  ${C}Folders in $RCLONE_REMOTE:${N}\n"
         rclone lsd "$RCLONE_REMOTE:" 2>/dev/null || echo "  Cannot connect"
         pause ;;
      4) read -rp "   New remote name: " V
         sed -i "s/^RCLONE_REMOTE=.*/RCLONE_REMOTE=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK] Remote set to: $V${N}"
         source "$SCRIPT_DIR/config.sh"; pause ;;
      5)
        hdr
        echo -e "${B}   GOOGLE DRIVE SETUP GUIDE${N}\n"
        echo -e "$LINE"
        echo -e "   Run in Termux:  ${C}rclone config${N}\n"
        echo -e "   ${Y}n${N}           -> New remote"
        echo -e "   name         -> ${G}gdrive${N}"
        echo -e "   Storage      -> choose ${G}Google Drive${N} number"
        echo -e "   client_id    -> Enter (leave blank)"
        echo -e "   client_secret-> Enter (leave blank)"
        echo -e "   scope        -> ${G}1${N}  (full access)"
        echo -e "   root_folder  -> Enter"
        echo -e "   service_acct -> Enter"
        echo -e "   Advanced?    -> ${G}n${N}"
        echo -e "   ${R}Web browser? -> n${N}  <- IMPORTANT!"
        echo -e "   ${Y}A URL appears -> open it in Chrome${N}"
        echo -e "   ${Y}Sign in with Google -> copy the code -> paste in Termux${N}"
        echo -e "   Shared drive?-> ${G}n${N}"
        echo -e "   Confirm?     -> ${G}y${N}"
        echo -e "   Quit         -> ${G}q${N}\n"
        echo -e "   Test: ${C}rclone lsd gdrive:${N}"
        pause ;;
      0) break ;;
    esac
  done
}

# ── Settings menu ─────────────────────────────────────────────
menu_settings() {
  while true; do
    hdr
    source "$SCRIPT_DIR/config.sh"
    echo -e "${B}   GENERAL SETTINGS${N}\n"
    echo -e "$LINE"
    echo -e "   WRITE_WAIT         = ${C}$WRITE_WAIT${N} sec"
    echo -e "   MAX_DEPTH          = ${C}$MAX_DEPTH${N}"
    echo -e "   UPLOAD_EXISTING    = ${C}$UPLOAD_EXISTING${N}"
    echo -e "   AUTO_PULL          = ${C}$AUTO_PULL_ENABLED${N}"
    echo -e "   AUTO_PULL_INTERVAL = ${C}${AUTO_PULL_INTERVAL}s${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Write wait (seconds after detecting file)"
    echo -e "   ${Y}[2]${N}  Max subfolder depth"
    echo -e "   ${Y}[3]${N}  Toggle upload existing files"
    echo -e "   ${Y}[4]${N}  Toggle auto-pull"
    echo -e "   ${Y}[5]${N}  Auto-pull interval"
    echo -e "   ${Y}[E]${N}  Edit config.sh directly (nano)"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) read -rp "   WRITE_WAIT (seconds): " V
         sed -i "s/^WRITE_WAIT=.*/WRITE_WAIT=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK]${N}"; pause ;;
      2) read -rp "   MAX_DEPTH: " V
         sed -i "s/^MAX_DEPTH=.*/MAX_DEPTH=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK]${N}"; pause ;;
      3) local V; [ "$UPLOAD_EXISTING" = "true" ] && V="false" || V="true"
         sed -i "s/^UPLOAD_EXISTING=.*/UPLOAD_EXISTING=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK] UPLOAD_EXISTING=$V${N}"; pause ;;
      4) local V; [ "$AUTO_PULL_ENABLED" = "true" ] && V="false" || V="true"
         sed -i "s/^AUTO_PULL_ENABLED=.*/AUTO_PULL_ENABLED=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK] AUTO_PULL=$V${N}"; pause ;;
      5) read -rp "   Interval (seconds): " V
         sed -i "s/^AUTO_PULL_INTERVAL=.*/AUTO_PULL_INTERVAL=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "  ${G}[OK]${N}"; pause ;;
      [Ee]) nano "$SCRIPT_DIR/config.sh"; pause ;;
      0) break ;;
    esac
  done
}

# ── Manual sync menu ──────────────────────────────────────────
menu_manual_sync() {
  hdr
  source "$SCRIPT_DIR/config.sh"
  source "$SCRIPT_DIR/scripts/logger.sh"
  source "$SCRIPT_DIR/scripts/telegram.sh"
  echo -e "${B}   MANUAL SYNC${N}\n"
  echo -e "$LINE"

  local i=1
  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r L D DIR <<< "$ENTRY"
    echo -e "   ${Y}[$i]${N}  $(basename "$L")  ${D}($DIR)${N}"
    ((i++))
  done
  echo -e "   ${C}[A]${N}  Sync all folders"
  echo -e "   ${D}[0]${N}  Back\n"
  read -rp "   Choose: " CH

  do_sync() {
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$1"
    echo ""
    if [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
      echo -e "  ${C}Uploading: $LOCAL_PATH --> $RCLONE_REMOTE:$DRIVE_PATH${N}"
      rclone copy "$LOCAL_PATH" "$RCLONE_REMOTE:$DRIVE_PATH" --progress 2>&1 | tail -8
    fi
    if [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]]; then
      echo -e "  ${C}Pulling: $RCLONE_REMOTE:$DRIVE_PATH --> $LOCAL_PATH${N}"
      mkdir -p "$LOCAL_PATH"
      rclone copy "$RCLONE_REMOTE:$DRIVE_PATH" "$LOCAL_PATH" --progress 2>&1 | tail -8
    fi
    echo -e "  ${G}[OK] Done${N}"
  }

  if [[ "$CH" == "A" || "$CH" == "a" ]]; then
    for ENTRY in "${SYNC_FOLDERS[@]}"; do do_sync "$ENTRY"; done
  elif [[ "$CH" =~ ^[0-9]+$ ]] && [ "$CH" -ge 1 ] && [ "$CH" -le "${#SYNC_FOLDERS[@]}" ]; then
    do_sync "${SYNC_FOLDERS[$((CH-1))]}"
  fi
  [ "$CH" != "0" ] && pause
}

# ── Logs menu ─────────────────────────────────────────────────
menu_logs() {
  while true; do
    hdr
    echo -e "${B}   LOGS${N}\n"
    echo -e "$LINE"
    local TOTAL
    TOTAL=$(wc -l < "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null || echo 0)
    echo -e "   Uploaded files : ${G}$TOTAL${N}"
    echo -e "   Log file       : ${D}$PROJECT_DIR/logs/watcher.log${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Show last 30 lines"
    echo -e "   ${Y}[2]${N}  Follow live (Ctrl+C to stop)"
    echo -e "   ${Y}[3]${N}  Show uploaded files"
    echo -e "   ${Y}[4]${N}  Clear log"
    echo -e "   ${Y}[5]${N}  Clear uploaded registry"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) echo ""; tail -30 "$PROJECT_DIR/logs/watcher.log" 2>/dev/null || echo "  No log yet"; pause ;;
      2) tail -f "$PROJECT_DIR/logs/watcher.log" 2>/dev/null ;;
      3) echo -e "\n  ${C}Uploaded files ($TOTAL):${N}\n"
         cat "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null | while read -r F; do
           echo "  + $(basename "$F")"
         done; pause ;;
      4) > "$PROJECT_DIR/logs/watcher.log"
         echo -e "  ${G}[OK] Log cleared${N}"; pause ;;
      5) read -rp "   This will let files re-upload. Confirm? [y/N]: " CONF
         [[ "$CONF" =~ ^[Yy]$ ]] && > "$PROJECT_DIR/logs/uploaded.txt" && \
           echo -e "  ${G}[OK] Registry cleared${N}" || echo "  Cancelled"
         pause ;;
      0) break ;;
    esac
  done
}

# ── MAIN MENU ─────────────────────────────────────────────────
while true; do
  hdr
  source "$SCRIPT_DIR/config.sh"

  local_watcher=$(watcher_status)
  local TOTAL
  TOTAL=$(wc -l < "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null || echo 0)
  DRIVE_OK=""; rclone lsd "$RCLONE_REMOTE:" &>/dev/null && DRIVE_OK="${G}OK${N}" || DRIVE_OK="${R}ERR${N}"
  DROPBOX_ST=$([ "$DROPBOX_SYNC_ENABLED" = "true" ] && echo "${G}ON${N}" || echo "${R}OFF${N}")
  TG_ST=$([ "$TELEGRAM_ENABLED" = "true" ] && echo "${G}ON${N}" || echo "${R}OFF${N}")

  echo -e "$LINE"
  printf "   Watcher    : "; watcher_status
  echo -e "   Drive      : $DRIVE_OK  |  Telegram: $TG_ST  |  Dropbox-sync: $DROPBOX_ST"
  echo -e "   Folders    : ${Y}${#SYNC_FOLDERS[@]}${N} tracked   |  Uploaded: ${G}${TOTAL}${N} files"
  echo -e "$LINE\n"
  echo -e "   ${G}[1]${N}  Start watcher"
  echo -e "   ${R}[2]${N}  Stop watcher"
  echo -e "   ${C}[3]${N}  Manage sync folders"
  echo -e "   ${C}[4]${N}  Dropbox-style sync"
  echo -e "   ${C}[5]${N}  Telegram notifications"
  echo -e "   ${C}[6]${N}  Google Drive / rclone"
  echo -e "   ${C}[7]${N}  Manual sync now"
  echo -e "   ${C}[8]${N}  General settings"
  echo -e "   ${C}[9]${N}  Logs"
  echo -e "   ${D}[0]${N}  Exit\n"
  read -rp "   Choose: " CH

  case "$CH" in
    1) bash "$SCRIPT_DIR/start.sh"; pause ;;
    2) bash "$SCRIPT_DIR/stop.sh"; pause ;;
    3) menu_folders ;;
    4) menu_dropbox ;;
    5) menu_telegram ;;
    6) menu_rclone ;;
    7) menu_manual_sync ;;
    8) menu_settings ;;
    9) menu_logs ;;
    0) echo -e "\n  ${D}Goodbye!${N}\n"; exit 0 ;;
  esac
done
