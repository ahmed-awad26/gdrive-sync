#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — Termux Auto Sync with Google Drive            ║
# ║  Copyright (c) 2025 Ahmed Awad                               ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ║  License : MIT                                               ║
# ╚══════════════════════════════════════════════════════════════╝
# config.sh — All project settings. Restart watcher after editing.

# ── rclone remote name (from: rclone config) ──────────────────
RCLONE_REMOTE="gdrive"

# ── Watched folders ───────────────────────────────────────────
# Format: "local_path|drive_path|direction"
# direction: up | down | both
SYNC_FOLDERS=(
  "$HOME/storage/dcim/Camera|GDriveSync/Camera|up"
  "$HOME/storage/downloads|GDriveSync/Downloads|up"
  # "$HOME/storage/shared/WhatsApp/Media|GDriveSync/WhatsApp|up"
  # "$HOME/storage/documents|GDriveSync/Documents|both"
)

# ── Dropbox-style full folder sync (bisync) ───────────────────
# Keeps a local folder 100% mirrored with Drive, like Dropbox.
# Uses rclone bisync — changes on either side are merged.
DROPBOX_SYNC_ENABLED="false"
DROPBOX_LOCAL_ROOT="$HOME/storage/shared/DriveSync"  # local root folder
DROPBOX_DRIVE_ROOT="DriveSync"                        # Drive folder name
DROPBOX_SYNC_INTERVAL=120  # Re-sync every N seconds (120 = 2 min)

# ── Telegram notifications ────────────────────────────────────
# Get BOT_TOKEN: chat @BotFather -> /newbot
# Get CHAT_ID  : chat @userinfobot
TELEGRAM_ENABLED="false"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_EVENTS="upload,download,error,start,stop"

# ── Sync behavior ─────────────────────────────────────────────
WRITE_WAIT=3              # Seconds to wait after detecting a new file
MAX_DEPTH=5               # Subfolder watch depth
UPLOAD_EXISTING="false"   # Upload pre-existing files on first run
AUTO_PULL_ENABLED="false" # Periodically pull from Drive
AUTO_PULL_INTERVAL=300    # Pull interval in seconds

# ── Paths ─────────────────────────────────────────────────────
PROJECT_DIR="$HOME/gdrive-sync"
LOG_MAX_LINES=1000
