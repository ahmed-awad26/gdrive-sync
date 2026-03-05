#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  GDrive Sync — One-command installer                         ║
# ║  Copyright (c) 2025 Ahmed Awad                               ║
# ║  https://github.com/ahmed-awad26/gdrive-sync                 ║
# ╚══════════════════════════════════════════════════════════════╝
# Run in Termux:
#   bash <(curl -fsSL https://raw.githubusercontent.com/ahmed-awad26/gdrive-sync/main/install.sh)

set -e
G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
R='\033[0;31m'; B='\033[1m'; D='\033[2m'; N='\033[0m'

REPO_URL="https://github.com/ahmed-awad26/gdrive-sync"
RAW_URL="https://raw.githubusercontent.com/ahmed-awad26/gdrive-sync/main"
INSTALL_DIR="$HOME/gdrive-sync"

step() { echo -e "\n${Y}>> $1${N}"; }
ok()   { echo -e "${G}   [OK] $1${N}"; }
err()  { echo -e "${R}   [ERR] $1${N}"; exit 1; }

clear
echo -e "${C}${B}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   ██████╗ ██████╗ ██╗██╗   ██╗███████╗  ║"
echo "  ║   ██╔══██╗██╔══██╗██║██║   ██║██╔════╝  ║"
echo "  ║   ██║  ██║██████╔╝██║██║   ██║█████╗    ║"
echo "  ║   ██║  ██║██╔══██╗██║╚██╗ ██╔╝██╔══╝    ║"
echo "  ║   ██████╔╝██║  ██║██║ ╚████╔╝ ███████╗  ║"
echo "  ║   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝  ║"
echo "  ║                                          ║"
echo "  ║      GDrive Sync — Installer             ║"
echo "  ║      by Ahmed Awad  @ahmed-awad26        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${N}"

# 1. Update & install packages
step "Updating Termux packages..."
pkg update -y -q && pkg upgrade -y -q
ok "Updated"

step "Installing dependencies: inotify-tools, rclone, curl, git..."
pkg install -y -q inotify-tools rclone curl git
ok "Dependencies installed"

if ! command -v termux-notification &>/dev/null; then
  echo -e "  ${Y}[WARN] Termux:API not found — local notifications disabled${N}"
  echo -e "  ${D}        Install from F-Droid: Termux:API${N}"
fi

# 2. Storage permission
step "Requesting storage permission..."
echo -e "  ${Y}A popup will appear — tap 'Allow'${N}"
sleep 1
termux-setup-storage 2>/dev/null || true
sleep 2
ok "Storage permission granted"

# 3. Clone project
step "Cloning project from GitHub..."
if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "  ${D}Project exists — pulling latest...${N}"
  cd "$INSTALL_DIR" && git pull origin main
elif [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi
ok "Project installed at: $INSTALL_DIR"

# 4. Permissions & dirs
step "Setting permissions..."
chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/scripts/*.sh
mkdir -p "$INSTALL_DIR/logs"
touch "$INSTALL_DIR/logs/uploaded.txt"
ok "Done"

# 5. Alias
step "Creating 'gsync' shortcut..."
ALIAS_LINE="alias gsync='bash $INSTALL_DIR/manage.sh'"
if ! grep -qF "alias gsync=" ~/.bashrc 2>/dev/null; then
  echo "$ALIAS_LINE" >> ~/.bashrc
  ok "Type 'gsync' after reopening Termux"
else
  ok "Alias already exists"
fi

# 6. rclone setup
echo ""
echo -e "${C}${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${B}  Next: Link your Google Drive account${N}"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}\n"
echo -e "  Setup Google Drive now?"
echo -e "  ${G}[Y]${N} Yes — open rclone config"
echo -e "  ${D}[N]${N} Later — from the manage panel\n"
read -rp "  Choose [Y/n]: " DO_RCLONE

if [[ "$DO_RCLONE" =~ ^[Yy]$ ]] || [ -z "$DO_RCLONE" ]; then
  echo ""
  echo -e "${Y}  rclone config guide:${N}"
  echo -e "  ${D}1. n -> New remote${N}"
  echo -e "  ${D}2. Name: gdrive${N}"
  echo -e "  ${D}3. Pick Google Drive from list${N}"
  echo -e "  ${D}4. Enter x4, scope=1, n, n${N}"
  echo -e "  ${G}  IMPORTANT: 'Use web browser?' -> choose n${N}"
  echo -e "  ${G}  Then open the URL in Chrome, sign in, paste code here${N}"
  echo -e "  ${D}5. n, y, q${N}\n"
  read -rp "  Press Enter to open rclone config..."
  rclone config
fi

# Done
echo ""
echo -e "${G}${B}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Installation complete!                 ║"
echo "  ║                                          ║"
echo "  ║   Commands:                              ║"
echo "  ║   gsync        — management panel        ║"
echo "  ║   ./start.sh   — start watcher           ║"
echo "  ║   ./stop.sh    — stop watcher            ║"
echo "  ║   ./status.sh  — show status             ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${N}"

read -rp "  Open management panel now? [Y/n]: " DO_MANAGE
[[ "$DO_MANAGE" =~ ^[Yy]$ ]] || [ -z "$DO_MANAGE" ] && exec bash "$INSTALL_DIR/manage.sh"
