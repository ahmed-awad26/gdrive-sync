#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Termux Auto Sync with Google Drive            ║
# ║  Copyright (c) 2025 Ahmed Awad                               ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ║  License : MIT                                               ║
# ╚══════════════════════════════════════════════════════════════╝
# manage.sh — Interactive management panel

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ── Colors ─────────────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[1;33m'
C='\033[0;36m'  B='\033[1m'     D='\033[2m'    N='\033[0m'
M='\033[0;35m'  W='\033[1;37m'

LINE="${D}──────────────────────────────────────────────────${N}"
DLINE="${D}══════════════════════════════════════════════════${N}"

# ── Header ─────────────────────────────────────────────────────
hdr() {
  local TITLE="${1:-GDrive Sync}"
  clear 2>/dev/null || printf '\033[2J\033[H'
  echo -e "${C}${B}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║                                                  ║"
  echo "  ║   ██████╗ ██████╗ ██╗██╗   ██╗███████╗          ║"
  echo "  ║   ██╔══██╗██╔══██╗██║██║   ██║██╔════╝          ║"
  echo "  ║   ██║  ██║██████╔╝██║██║   ██║█████╗            ║"
  echo "  ║   ██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝            ║"
  echo "  ║   ██████╔╝██║  ██║██║ ╚████╔╝ ███████╗          ║"
  echo "  ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝          ║"
  printf "  ║   %-48s ║\n" "  $TITLE"
  echo "  ║   by Ahmed Awad  @ahmed-awad26                  ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${N}"
}

pause() { echo ""; read -rp "   Press Enter to continue..." _; }

# ── Helper: watcher running? ───────────────────────────────────
is_running() {
  [ -f "$PROJECT_DIR/logs/watcher.pid" ] && \
    kill -0 "$(cat "$PROJECT_DIR/logs/watcher.pid")" 2>/dev/null
}

watcher_badge() {
  if is_running; then
    printf "${G}● RUNNING${N}  PID: %s" "$(cat "$PROJECT_DIR/logs/watcher.pid")"
  else
    printf "${R}○ STOPPED${N}"
  fi
}

drive_badge() {
  rclone lsd "$RCLONE_REMOTE:" &>/dev/null \
    && printf "${G}● Connected${N}" \
    || printf "${R}✗ No connection${N}"
}

# ── Helper: human-readable bytes ──────────────────────────────
human_bytes() {
  local BYTES="$1"
  if   [ "$BYTES" -ge 1073741824 ] 2>/dev/null; then
    printf "%.1f GB" "$(echo "scale=1; $BYTES/1073741824" | bc 2>/dev/null || echo "?")"
  elif [ "$BYTES" -ge 1048576 ] 2>/dev/null; then
    printf "%.1f MB" "$(echo "scale=1; $BYTES/1048576" | bc 2>/dev/null || echo "?")"
  elif [ "$BYTES" -ge 1024 ] 2>/dev/null; then
    printf "%.1f KB" "$(echo "scale=1; $BYTES/1024" | bc 2>/dev/null || echo "?")"
  else
    printf "%s B" "$BYTES"
  fi
}

# ── Drive storage quota ────────────────────────────────────────
get_drive_quota() {
  local RAW
  RAW="$(rclone about "$RCLONE_REMOTE:" --json 2>/dev/null)"
  if [ -z "$RAW" ]; then
    echo "${R}  Could not retrieve quota (check connection)${N}"
    return
  fi

  local USED TOTAL FREE TRASH
  USED=$(echo  "$RAW" | grep -o '"used":[0-9]*'    | grep -o '[0-9]*')
  TOTAL=$(echo "$RAW" | grep -o '"total":[0-9]*'   | grep -o '[0-9]*')
  FREE=$(echo  "$RAW" | grep -o '"free":[0-9]*'    | grep -o '[0-9]*')
  TRASH=$(echo "$RAW" | grep -o '"trashed":[0-9]*' | grep -o '[0-9]*')

  local USED_H TOTAL_H FREE_H TRASH_H
  USED_H=$(human_bytes  "${USED:-0}")
  TOTAL_H=$(human_bytes "${TOTAL:-0}")
  FREE_H=$(human_bytes  "${FREE:-0}")
  TRASH_H=$(human_bytes "${TRASH:-0}")

  # Build usage bar
  local BAR=""
  if [ -n "$USED" ] && [ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
    local PCT=$(( USED * 20 / TOTAL ))
    local FILLED=0
    BAR="["
    while [ $FILLED -lt $PCT ];  do BAR="${BAR}█"; FILLED=$(( FILLED + 1 )); done
    while [ $FILLED -lt 20 ];    do BAR="${BAR}░"; FILLED=$(( FILLED + 1 )); done
    BAR="${BAR}]"
    local PCT_NUM=$(( USED * 100 / TOTAL ))
    if   [ $PCT_NUM -ge 90 ]; then BAR="${R}${BAR} ${PCT_NUM}%${N}"
    elif [ $PCT_NUM -ge 70 ]; then BAR="${Y}${BAR} ${PCT_NUM}%${N}"
    else                           BAR="${G}${BAR} ${PCT_NUM}%${N}"
    fi
  fi

  echo -e "   ${W}Storage Quota:${N}  $USED_H used  /  $TOTAL_H total  |  ${G}$FREE_H free${N}"
  [ -n "$BAR" ] && echo -e "   $BAR"
  [ -n "$TRASH_H" ] && [ "${TRASH:-0}" -gt 0 ] && \
    echo -e "   ${D}Trash: $TRASH_H${N}"
}

# ═══════════════════════════════════════════════════════════════
#   CLOUD EXPLORER — browse drive folders, show size & contents
# ═══════════════════════════════════════════════════════════════
menu_cloud_explorer() {
  local CURRENT_PATH=""

  while true; do
    hdr "Cloud Explorer"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE"

    local DISPLAY_PATH="${RCLONE_REMOTE}:/${CURRENT_PATH}"
    echo -e "   ${W}Location:${N}  ${C}${DISPLAY_PATH}${N}\n"

    # ── Get folder list ──────────────────────────────────────
    local FOLDERS=()
    local FOLDER_SIZES=()
    local FOLDER_COUNTS=()

    echo -e "   ${D}Loading folder list...${N}"
    mapfile -t RAW_FOLDERS < <(
      rclone lsd "$RCLONE_REMOTE:$CURRENT_PATH" 2>/dev/null \
        | awk '{print $NF}' | sort
    )

    # ── Get file list ────────────────────────────────────────
    local FILES=()
    local FILE_SIZES=()
    mapfile -t RAW_FILES_LINE < <(
      rclone ls "$RCLONE_REMOTE:$CURRENT_PATH" --max-depth 1 2>/dev/null \
        | awk '{size=$1; $1=""; sub(/^ /,""); print size"|"$0}' | sort -k2
    )

    clear 2>/dev/null || printf '\033[2J\033[H'
    hdr "Cloud Explorer"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE"
    echo -e "   ${W}Location:${N}  ${C}${DISPLAY_PATH}${N}\n"

    # ── Folder size summary ──────────────────────────────────
    local TOTAL_SIZE=0
    local TOTAL_FILES=0
    for LINE_DATA in "${RAW_FILES_LINE[@]}"; do
      local SZ="${LINE_DATA%%|*}"
      TOTAL_SIZE=$(( TOTAL_SIZE + ${SZ:-0} ))
      TOTAL_FILES=$(( TOTAL_FILES + 1 ))
    done
    local TOTAL_H
    TOTAL_H=$(human_bytes "$TOTAL_SIZE")

    echo -e "   ${W}Contents:${N}  ${Y}${#RAW_FOLDERS[@]}${N} folders  |  ${G}${TOTAL_FILES}${N} files  |  Size: ${C}${TOTAL_H}${N}\n"
    echo -e "$LINE"

    local IDX=1

    # ── Show parent dir option ───────────────────────────────
    if [ -n "$CURRENT_PATH" ]; then
      echo -e "   ${D}[..]${N}  ${Y}↑ Go up${N}"
      echo ""
    fi

    # ── List folders ─────────────────────────────────────────
    for F in "${RAW_FOLDERS[@]}"; do
      [ -z "$F" ] && continue
      FOLDERS+=("$F")
      printf "   ${Y}[%2d]${N}  ${C}📁 %-40s${N}\n" "$IDX" "$F/"
      IDX=$(( IDX + 1 ))
    done

    # ── List files ───────────────────────────────────────────
    local FILE_IDX_START=$IDX
    for LINE_DATA in "${RAW_FILES_LINE[@]}"; do
      local SZ="${LINE_DATA%%|*}"
      local FN="${LINE_DATA#*|}"
      local SZ_H
      SZ_H=$(human_bytes "${SZ:-0}")
      FILES+=("$FN")
      FILE_SIZES+=("$SZ_H")
      printf "   ${D}[%2d]${N}  📄 %-38s  ${D}%s${N}\n" "$IDX" "$FN" "$SZ_H"
      IDX=$(( IDX + 1 ))
    done

    echo ""
    echo -e "$LINE"
    echo -e "   ${G}[S]${N}  Show full folder size (slower)"
    echo -e "   ${D}[0]${N}  Back to main menu\n"

    read -rp "   Choose [number / .. / S / 0]: " CH

    # ── Navigate ──────────────────────────────────────────────
    if [ "$CH" = ".." ] && [ -n "$CURRENT_PATH" ]; then
      CURRENT_PATH="${CURRENT_PATH%/*}"
      [ "$CURRENT_PATH" = "$RCLONE_REMOTE:" ] && CURRENT_PATH=""
      continue
    fi

    if [ "$CH" = "0" ]; then
      break
    fi

    if [[ "$CH" =~ ^[Ss]$ ]]; then
      echo ""
      echo -e "   ${C}Computing full size of ${DISPLAY_PATH} ...${N}"
      local FULL_SIZE
      FULL_SIZE=$(rclone size "$RCLONE_REMOTE:$CURRENT_PATH" 2>/dev/null)
      echo ""
      echo -e "$FULL_SIZE" | while IFS= read -r LINE_OUT; do
        echo -e "   $LINE_OUT"
      done
      pause
      continue
    fi

    if [[ "$CH" =~ ^[0-9]+$ ]]; then
      # Is it a folder?
      local FOLDER_IDX=$(( CH - 1 ))
      if [ "$FOLDER_IDX" -ge 0 ] && [ "$FOLDER_IDX" -lt "${#FOLDERS[@]}" ]; then
        if [ -z "$CURRENT_PATH" ]; then
          CURRENT_PATH="${FOLDERS[$FOLDER_IDX]}"
        else
          CURRENT_PATH="${CURRENT_PATH}/${FOLDERS[$FOLDER_IDX]}"
        fi
        continue
      fi
      # Is it a file?
      local FILE_REAL_IDX=$(( CH - FILE_IDX_START ))
      if [ "$FILE_REAL_IDX" -ge 0 ] && [ "$FILE_REAL_IDX" -lt "${#FILES[@]}" ]; then
        echo ""
        echo -e "   ${W}File:${N}  ${FILES[$FILE_REAL_IDX]}"
        echo -e "   ${W}Size:${N}  ${FILE_SIZES[$FILE_REAL_IDX]}"
        echo -e "   ${W}Path:${N}  ${DISPLAY_PATH}/${FILES[$FILE_REAL_IDX]}"
        pause
      fi
    fi
  done
}

# ═══════════════════════════════════════════════════════════════
#   CLOUD STORAGE STATUS
# ═══════════════════════════════════════════════════════════════
menu_cloud_status() {
  hdr "Cloud Storage Status"
  source "$SCRIPT_DIR/config.sh"
  echo -e "$LINE"
  echo -e "   ${W}Remote:${N}  ${C}${RCLONE_REMOTE}${N}  |  $(drive_badge)\n"

  echo -e "   ${D}Fetching quota info...${N}"
  get_drive_quota

  echo ""
  echo -e "$LINE"
  echo -e "   ${W}Sync Folder Sizes on Drive:${N}\n"

  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$ENTRY"
    local ARROW
    case "$DIRECTION" in
      up)   ARROW="${G}↑ up${N}"   ;;
      down) ARROW="${C}↓ down${N}" ;;
      both) ARROW="${Y}↕ both${N}" ;;
    esac

    printf "   ${Y}%-30s${N}  (%s)\n" "$(basename "$LOCAL_PATH")" "$DIRECTION"
    echo -ne "   ${D}   Drive path:${N} ${C}${RCLONE_REMOTE}:${DRIVE_PATH}${N} ... "

    local SIZE_OUT
    SIZE_OUT=$(rclone size "$RCLONE_REMOTE:$DRIVE_PATH" 2>/dev/null)
    if [ -z "$SIZE_OUT" ]; then
      echo -e "${R}not found / empty${N}"
    else
      local F_COUNT F_SIZE
      F_COUNT=$(echo "$SIZE_OUT" | grep -i "Total objects" | grep -o '[0-9,]*' | tr -d ',')
      F_SIZE=$(echo  "$SIZE_OUT" | grep -i "Total size"    | sed 's/.*Total size: //')
      printf "${G}%s files${N}  ${C}%s${N}\n" "${F_COUNT:-0}" "${F_SIZE:-?}"
    fi
    echo ""
  done

  echo -e "$LINE"
  pause
}

# ═══════════════════════════════════════════════════════════════
#   FOLDER PICKER — select which folder the watcher works on
# ═══════════════════════════════════════════════════════════════
pick_folder_for_action() {
  # $1 = action description string
  local ACTION="${1:-Select}"
  source "$SCRIPT_DIR/config.sh"

  echo ""
  echo -e "   ${W}${ACTION}${N}\n"
  echo -e "$LINE"

  local i=1
  for ENTRY in "${SYNC_FOLDERS[@]}"; do
    IFS='|' read -r L D DIR <<< "$ENTRY"
    local ARROW
    case "$DIR" in
      up)   ARROW="${G}↑${N}" ;;
      down) ARROW="${C}↓${N}" ;;
      both) ARROW="${Y}↕${N}" ;;
    esac
    printf "   ${Y}[%d]${N}  %s  %s  ${C}%s${N}  ${D}(%s)${N}\n" \
      "$i" "$ARROW" "$(basename "$L")" "$RCLONE_REMOTE:$D" "$DIR"
    i=$(( i + 1 ))
  done
  echo -e "   ${C}[A]${N}  All folders"
  echo -e "   ${D}[0]${N}  Cancel\n"
  read -rp "   Choose: " PICK_CH
  echo "$PICK_CH"
}

# ═══════════════════════════════════════════════════════════════
#   SYNC FOLDERS MENU
# ═══════════════════════════════════════════════════════════════
menu_folders() {
  while true; do
    hdr "Sync Folders"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE\n"

    local i=1
    for ENTRY in "${SYNC_FOLDERS[@]}"; do
      IFS='|' read -r L D DIR <<< "$ENTRY"
      local ARROW
      case "$DIR" in
        up)   ARROW="${G}──►${N}" ;;
        down) ARROW="${C}◄──${N}" ;;
        both) ARROW="${Y}◄──►${N}" ;;
      esac
      printf "   ${Y}[%d]${N}  %-35s\n" "$i" "$(basename "$L")"
      echo -e "         $ARROW  ${C}${RCLONE_REMOTE}:${D}${N}  ${D}($DIR)${N}"
      echo -e "         ${D}Local:${N} $L"
      echo ""
      i=$(( i + 1 ))
    done

    echo -e "$LINE"
    echo -e "   ${G}[A]${N}  Add new sync folder"
    echo -e "   ${R}[D]${N}  Remove a folder"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      [Aa])
        echo ""
        echo -e "   ${W}Add New Sync Folder${N}\n"
        read -rp "   Local path  (e.g. $HOME/storage/downloads): " NEW_LOCAL
        read -rp "   Drive path  (e.g. GDriveSync/Downloads):    " NEW_DRIVE
        echo -e "   Direction:  ${Y}[1]${N} Upload only  ${Y}[2]${N} Download only  ${Y}[3]${N} Both"
        read -rp "   Choose [1-3]: " DIR_CH
        case "$DIR_CH" in
          1) NEW_DIR="up"   ;;
          2) NEW_DIR="down" ;;
          3) NEW_DIR="both" ;;
          *) echo -e "${R}   Invalid${N}"; pause; continue ;;
        esac
        local NEW_ENTRY="  \"$NEW_LOCAL|$NEW_DRIVE|$NEW_DIR\""
        sed -i "/^SYNC_FOLDERS=(/,/^)/{/^)/i\\$NEW_ENTRY
}" "$SCRIPT_DIR/config.sh"
        echo -e "\n   ${G}[OK] Folder added!${N}"
        source "$SCRIPT_DIR/config.sh"; pause ;;
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
" 2>/dev/null && echo -e "\n   ${G}[OK] Removed!${N}" || echo -e "\n   ${R}[ERR] Edit config.sh manually${N}"
          source "$SCRIPT_DIR/config.sh"
        else
          echo -e "   ${R}[ERR] Invalid number${N}"
        fi
        pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   DROPBOX BISYNC MENU
# ═══════════════════════════════════════════════════════════════
menu_dropbox() {
  while true; do
    hdr "Dropbox-Style Sync"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE\n"
    echo -e "   ${D}Keeps a local folder perfectly mirrored with Drive.${N}"
    echo -e "   ${D}Changes on either side are merged automatically.${N}\n"
    echo -e "   Enabled    :  $([ "$DROPBOX_SYNC_ENABLED" = "true" ] && echo "${G}YES${N}" || echo "${R}NO${N}")"
    echo -e "   Local root :  ${C}$DROPBOX_LOCAL_ROOT${N}"
    echo -e "   Drive root :  ${C}$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT${N}"
    echo -e "   Interval   :  ${C}${DROPBOX_SYNC_INTERVAL}s${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Toggle on / off"
    echo -e "   ${Y}[2]${N}  Change local root folder"
    echo -e "   ${Y}[3]${N}  Change Drive root folder"
    echo -e "   ${Y}[4]${N}  Change sync interval"
    echo -e "   ${Y}[5]${N}  Run bisync NOW (manual)"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) local NV; [ "$DROPBOX_SYNC_ENABLED" = "true" ] && NV="false" || NV="true"
         sed -i "s/^DROPBOX_SYNC_ENABLED=.*/DROPBOX_SYNC_ENABLED=\"$NV\"/" "$SCRIPT_DIR/config.sh"
         echo -e "\n   ${G}[OK] Dropbox sync: $NV${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      2) read -rp "   New local root path: " V
         sed -i "s|^DROPBOX_LOCAL_ROOT=.*|DROPBOX_LOCAL_ROOT=\"$V\"|" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      3) read -rp "   New Drive root name: " V
         sed -i "s/^DROPBOX_DRIVE_ROOT=.*/DROPBOX_DRIVE_ROOT=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      4) read -rp "   Interval (seconds): " V
         sed -i "s/^DROPBOX_SYNC_INTERVAL=.*/DROPBOX_SYNC_INTERVAL=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      5)
        echo ""
        source "$SCRIPT_DIR/config.sh"
        mkdir -p "$DROPBOX_LOCAL_ROOT"
        echo -e "   ${C}Bisync: $DROPBOX_LOCAL_ROOT <-> $RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT${N}\n"
        BISYNC_FLAG=""
        [ ! -d "$HOME/.config/rclone/bisync" ] && BISYNC_FLAG="--resync" && \
          echo -e "   ${Y}First run — using --resync${N}"
        rclone bisync "$DROPBOX_LOCAL_ROOT" "$RCLONE_REMOTE:$DROPBOX_DRIVE_ROOT" \
          $BISYNC_FLAG --create-empty-src-dirs --compare size,modtime,checksum \
          --resilient --force --progress 2>&1 | tail -20
        echo -e "\n   ${G}[OK] Bisync complete!${N}"; pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   TELEGRAM MENU
# ═══════════════════════════════════════════════════════════════
menu_telegram() {
  while true; do
    hdr "Telegram Notifications"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE\n"
    echo -e "   Enabled  :  $([ "$TELEGRAM_ENABLED" = "true" ] && echo "${G}YES${N}" || echo "${R}NO${N}")"
    echo -e "   Token    :  ${D}${TELEGRAM_BOT_TOKEN:-<not set>}${N}"
    echo -e "   Chat ID  :  ${D}${TELEGRAM_CHAT_ID:-<not set>}${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Toggle on / off"
    echo -e "   ${Y}[2]${N}  Set Bot Token"
    echo -e "   ${Y}[3]${N}  Set Chat ID"
    echo -e "   ${Y}[4]${N}  Test connection"
    echo -e "   ${Y}[5]${N}  Setup guide"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) local NV; [ "$TELEGRAM_ENABLED" = "true" ] && NV="false" || NV="true"
         sed -i "s/^TELEGRAM_ENABLED=.*/TELEGRAM_ENABLED=\"$NV\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Telegram: $NV${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      2) read -rp "   Enter BOT_TOKEN: " V
         sed -i "s/^TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      3) read -rp "   Enter CHAT_ID: " V
         sed -i "s/^TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Saved${N}"; source "$SCRIPT_DIR/config.sh"; pause ;;
      4) echo ""; source "$SCRIPT_DIR/scripts/telegram.sh"; tg_test; pause ;;
      5)
        hdr "Telegram Setup Guide"
        echo -e "$LINE\n"
        echo -e "   ${Y}Step 1 — Create a Bot:${N}"
        echo -e "   • Open Telegram → search ${C}@BotFather${N}"
        echo -e "   • Send: /newbot  →  choose a name"
        echo -e "   • Copy the ${G}Token${N}\n"
        echo -e "   ${Y}Step 2 — Get your Chat ID:${N}"
        echo -e "   • Search ${C}@userinfobot${N} → send any message"
        echo -e "   • Copy the ${G}Id${N}\n"
        echo -e "   ${Y}Step 3 — Activate:${N}"
        echo -e "   • Find your bot in Telegram → press Start\n"
        echo -e "   ${Y}Step 4:${N}"
        echo -e "   • Enter Token in [2]  |  Chat ID in [3]"
        echo -e "   • Enable in [1]  |  Test in [4]"
        pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   GOOGLE DRIVE / RCLONE MENU
# ═══════════════════════════════════════════════════════════════
menu_rclone() {
  while true; do
    hdr "Google Drive / rclone"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE\n"
    echo -e "   Remote  :  ${C}$RCLONE_REMOTE${N}"
    echo -e "   Status  :  $(drive_badge)\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Setup Google Drive  (rclone config)"
    echo -e "   ${Y}[2]${N}  Test connection"
    echo -e "   ${Y}[3]${N}  Browse Drive root folders"
    echo -e "   ${Y}[4]${N}  Change remote name"
    echo -e "   ${Y}[5]${N}  Step-by-step setup guide"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) echo -e "\n   ${Y}Tip: When asked 'Use web browser?' → choose [n]${N}\n"
         read -rp "   Press Enter to open rclone config..."
         rclone config; pause ;;
      2) echo ""
         rclone lsd "$RCLONE_REMOTE:" &>/dev/null \
           && echo -e "   ${G}[OK] Connected to $RCLONE_REMOTE!${N}" \
           || echo -e "   ${R}[ERR] Connection failed — run rclone config${N}"
         pause ;;
      3) echo -e "\n   ${C}Root folders in $RCLONE_REMOTE:${N}\n"
         rclone lsd "$RCLONE_REMOTE:" 2>/dev/null | awk '{printf "   📁 %s\n", $NF}' \
           || echo "   Cannot connect"
         pause ;;
      4) read -rp "   New remote name: " V
         sed -i "s/^RCLONE_REMOTE=.*/RCLONE_REMOTE=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] Remote set to: $V${N}"
         source "$SCRIPT_DIR/config.sh"; pause ;;
      5)
        hdr "Google Drive Setup Guide"
        echo -e "$LINE\n"
        echo -e "   Run in Termux:  ${C}rclone config${N}\n"
        echo -e "   ${Y}n${N}            → New remote"
        echo -e "   name         → ${G}gdrive${N}"
        echo -e "   Storage      → choose ${G}Google Drive${N}"
        echo -e "   client_id    → Enter  (leave blank)"
        echo -e "   client_secret→ Enter  (leave blank)"
        echo -e "   scope        → ${G}1${N}  (full access)"
        echo -e "   root_folder  → Enter"
        echo -e "   service_acct → Enter"
        echo -e "   Advanced?    → ${G}n${N}"
        echo -e "   ${R}Web browser? → n${N}  ← IMPORTANT"
        echo -e "   ${Y}URL appears  → open in Chrome, sign in, paste code${N}"
        echo -e "   Shared drive?→ ${G}n${N}"
        echo -e "   Confirm?     → ${G}y${N}  →  Quit: ${G}q${N}\n"
        echo -e "   Test: ${C}rclone lsd gdrive:${N}"
        pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   MANUAL SYNC — with folder picker
# ═══════════════════════════════════════════════════════════════
menu_manual_sync() {
  hdr "Manual Sync"
  source "$SCRIPT_DIR/config.sh"
  source "$SCRIPT_DIR/scripts/logger.sh"
  source "$SCRIPT_DIR/scripts/telegram.sh"
  echo -e "$LINE"

  CH=$(pick_folder_for_action "Choose folder to sync manually")

  do_sync() {
    IFS='|' read -r LOCAL_PATH DRIVE_PATH DIRECTION <<< "$1"
    echo ""
    if [[ "$DIRECTION" == "up" || "$DIRECTION" == "both" ]]; then
      echo -e "   ${C}Uploading: $LOCAL_PATH  →  $RCLONE_REMOTE:$DRIVE_PATH${N}"
      rclone copy "$LOCAL_PATH" "$RCLONE_REMOTE:$DRIVE_PATH" --progress 2>&1 | tail -8
    fi
    if [[ "$DIRECTION" == "down" || "$DIRECTION" == "both" ]]; then
      echo -e "   ${C}Pulling:   $RCLONE_REMOTE:$DRIVE_PATH  →  $LOCAL_PATH${N}"
      mkdir -p "$LOCAL_PATH"
      rclone copy "$RCLONE_REMOTE:$DRIVE_PATH" "$LOCAL_PATH" --progress 2>&1 | tail -8
    fi
    echo -e "   ${G}[OK] Done${N}"
  }

  if [[ "$CH" == "A" || "$CH" == "a" ]]; then
    for ENTRY in "${SYNC_FOLDERS[@]}"; do do_sync "$ENTRY"; done
    pause
  elif [[ "$CH" =~ ^[0-9]+$ ]] && [ "$CH" -ge 1 ] && [ "$CH" -le "${#SYNC_FOLDERS[@]}" ]; then
    do_sync "${SYNC_FOLDERS[$((CH-1))]}"
    pause
  fi
}

# ═══════════════════════════════════════════════════════════════
#   GENERAL SETTINGS
# ═══════════════════════════════════════════════════════════════
menu_settings() {
  while true; do
    hdr "General Settings"
    source "$SCRIPT_DIR/config.sh"
    echo -e "$LINE\n"
    echo -e "   WRITE_WAIT          =  ${C}${WRITE_WAIT}s${N}   ${D}(wait after new file detected)${N}"
    echo -e "   MAX_DEPTH           =  ${C}${MAX_DEPTH}${N}    ${D}(subfolder watch depth)${N}"
    echo -e "   UPLOAD_EXISTING     =  ${C}${UPLOAD_EXISTING}${N}"
    echo -e "   AUTO_PULL           =  ${C}${AUTO_PULL_ENABLED}${N}"
    echo -e "   AUTO_PULL_INTERVAL  =  ${C}${AUTO_PULL_INTERVAL}s${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Write wait  (seconds after file detected)"
    echo -e "   ${Y}[2]${N}  Max subfolder depth"
    echo -e "   ${Y}[3]${N}  Toggle upload existing files"
    echo -e "   ${Y}[4]${N}  Toggle auto-pull"
    echo -e "   ${Y}[5]${N}  Auto-pull interval"
    echo -e "   ${Y}[E]${N}  Edit config.sh directly  (nano)"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) read -rp "   WRITE_WAIT (seconds): " V
         sed -i "s/^WRITE_WAIT=.*/WRITE_WAIT=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK]${N}"; pause ;;
      2) read -rp "   MAX_DEPTH: " V
         sed -i "s/^MAX_DEPTH=.*/MAX_DEPTH=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK]${N}"; pause ;;
      3) local V; [ "$UPLOAD_EXISTING" = "true" ] && V="false" || V="true"
         sed -i "s/^UPLOAD_EXISTING=.*/UPLOAD_EXISTING=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] UPLOAD_EXISTING=$V${N}"; pause ;;
      4) local V; [ "$AUTO_PULL_ENABLED" = "true" ] && V="false" || V="true"
         sed -i "s/^AUTO_PULL_ENABLED=.*/AUTO_PULL_ENABLED=\"$V\"/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK] AUTO_PULL=$V${N}"; pause ;;
      5) read -rp "   Interval (seconds): " V
         sed -i "s/^AUTO_PULL_INTERVAL=.*/AUTO_PULL_INTERVAL=$V/" "$SCRIPT_DIR/config.sh"
         echo -e "   ${G}[OK]${N}"; pause ;;
      [Ee]) nano "$SCRIPT_DIR/config.sh"; pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   LOGS MENU
# ═══════════════════════════════════════════════════════════════
menu_logs() {
  while true; do
    hdr "Logs"
    echo -e "$LINE\n"
    local TOTAL
    TOTAL=$(wc -l < "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null || echo 0)
    echo -e "   Uploaded files  :  ${G}$TOTAL${N}"
    echo -e "   Log file        :  ${D}$PROJECT_DIR/logs/watcher.log${N}\n"
    echo -e "$LINE"
    echo -e "   ${Y}[1]${N}  Show last 30 lines"
    echo -e "   ${Y}[2]${N}  Follow live  (Ctrl+C to stop)"
    echo -e "   ${Y}[3]${N}  List uploaded files"
    echo -e "   ${Y}[4]${N}  Clear log"
    echo -e "   ${Y}[5]${N}  Clear uploaded registry"
    echo -e "   ${D}[0]${N}  Back\n"
    read -rp "   Choose: " CH

    case "$CH" in
      1) echo ""; tail -30 "$PROJECT_DIR/logs/watcher.log" 2>/dev/null || echo "   No log yet"; pause ;;
      2) tail -f "$PROJECT_DIR/logs/watcher.log" 2>/dev/null ;;
      3) echo -e "\n   ${C}Uploaded files ($TOTAL):${N}\n"
         cat "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null | while read -r F; do
           echo "   + $(basename "$F")"
         done; pause ;;
      4) > "$PROJECT_DIR/logs/watcher.log"
         echo -e "   ${G}[OK] Log cleared${N}"; pause ;;
      5) read -rp "   This allows files to re-upload. Confirm? [y/N]: " CONF
         [[ "$CONF" =~ ^[Yy]$ ]] && > "$PROJECT_DIR/logs/uploaded.txt" && \
           echo -e "   ${G}[OK] Registry cleared${N}" || echo "   Cancelled"
         pause ;;
      0) break ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════
#   MAIN MENU
# ═══════════════════════════════════════════════════════════════
while true; do
  source "$SCRIPT_DIR/config.sh"

  # Collect status values
  TOTAL=$(wc -l < "$PROJECT_DIR/logs/uploaded.txt" 2>/dev/null || echo 0)
  DROPBOX_ST=$([ "$DROPBOX_SYNC_ENABLED" = "true" ] && echo "${G}ON${N}"  || echo "${R}OFF${N}")
  TG_ST=$(     [ "$TELEGRAM_ENABLED"     = "true" ] && echo "${G}ON${N}"  || echo "${R}OFF${N}")

  hdr "Management Panel"

  # ── Status dashboard ─────────────────────────────────────────
  echo -e "$DLINE"
  printf "   %-20s " "Watcher:"; watcher_badge; echo ""
  printf "   %-20s " "Google Drive:";            drive_badge; echo ""
  echo -e "   Telegram  : $TG_ST   |   Dropbox-sync : $DROPBOX_ST"
  echo -e "   Folders   : ${Y}${#SYNC_FOLDERS[@]}${N} tracked   |   Uploaded : ${G}${TOTAL}${N} files"
  echo -e "$DLINE\n"

  # ── Menu items ────────────────────────────────────────────────
  echo -e "   ${G}[1]${N}  ▶  Start watcher"
  echo -e "   ${R}[2]${N}  ■  Stop watcher"
  echo -e "   ${C}[3]${N}  📁  Manage sync folders"
  echo -e "   ${C}[4]${N}  🔄  Dropbox-style sync  (bisync)"
  echo -e "   ${C}[5]${N}  📬  Telegram notifications"
  echo -e "   ${C}[6]${N}  ☁️   Google Drive / rclone"
  echo -e "   ${C}[7]${N}  ⚡  Manual sync now"
  echo -e "   ${C}[8]${N}  ⚙️   General settings"
  echo -e "   ${C}[9]${N}  📋  Logs"
  echo -e "   ${M}[C]${N}  ☁️   Cloud storage status  (quota)"
  echo -e "   ${M}[E]${N}  🔍  Cloud explorer  (browse Drive files)"
  echo -e "   ${D}[0]${N}  ✕  Exit\n"

  read -rp "   Choose: " CH

  case "$CH" in
    1) bash "$SCRIPT_DIR/start.sh"; pause ;;
    2) bash "$SCRIPT_DIR/stop.sh";  pause ;;
    3) menu_folders ;;
    4) menu_dropbox ;;
    5) menu_telegram ;;
    6) menu_rclone ;;
    7) menu_manual_sync ;;
    8) menu_settings ;;
    9) menu_logs ;;
    [Cc]) menu_cloud_status ;;
    [Ee]) menu_cloud_explorer ;;
    0) echo -e "\n   ${D}Goodbye!${N}\n"; exit 0 ;;
  esac
done
