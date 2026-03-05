<div align="center">

```
 █████╗ ██╗    ██╗
██╔══██╗██║    ██║
███████║██║ █╗ ██║
██╔══██║██║███╗██║
██║  ██║╚███╔███╔╝
╚═╝  ╚═╝ ╚══╝╚══╝
```

# ☁️ GDrive Sync

> **Termux-powered automatic sync between your Android phone and Google Drive**
> مزامنة تلقائية بين هاتف Android و Google Drive عبر Termux

[![GitHub](https://img.shields.io/badge/GitHub-ahmed--awad26-181717?style=flat-square&logo=github)](https://github.com/ahmed-awad26)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Termux%20%7C%20Android-black?style=flat-square&logo=android)](https://termux.dev)
[![Made with](https://img.shields.io/badge/Made%20with-Bash-4EAA25?style=flat-square&logo=gnubash)](https://www.gnu.org/software/bash/)

</div>

---

## 🇬🇧 English

### What is GDrive Sync?

GDrive Sync is a Termux Bash project that monitors folders on your Android phone and automatically uploads new files to **Google Drive** the moment they appear — with support for full **Dropbox-style bidirectional sync**, multiple folders, and **Telegram notifications**.

No root required. No cloud app needed. Just Termux + rclone.

---

### ✨ Features

| Feature | Description |
|---|---|
| ⚡ **Instant detection** | Detects new files immediately via `inotifywait` |
| 📁 **Multiple folders** | Track unlimited folders simultaneously |
| 🔄 **Bidirectional sync** | Upload only / Download only / Both directions |
| 🔁 **Dropbox-style sync** | Full mirror of any folder, just like Dropbox |
| 📱 **Telegram alerts** | Instant notifications for every sync event |
| 🛠️ **Interactive panel** | Manage everything from a menu — no file editing needed |
| ⏱️ **Auto-pull** | Periodically pulls Drive changes to phone |
| 🔒 **Safe dedup** | Never re-uploads files already synced |

---

### 🚀 Install — One Command

Open **Termux** and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ahmed-awad26/gdrive-sync/main/install.sh)
```

The installer will automatically:
1. Update Termux & install `inotify-tools`, `rclone`, `curl`, `git`
2. Grant storage permission
3. Clone the project
4. Walk you through Google Drive setup
5. Launch the management panel

---

### ☁️ Linking Google Drive

> This is the only manual step — done once, forever.

```bash
rclone config
```

Follow this table:

| Prompt | What to enter |
|---|---|
| New remote | `n` |
| Name | `gdrive` |
| Storage type | Number next to **Google Drive** |
| client_id | *(press Enter — leave blank)* |
| client_secret | *(press Enter — leave blank)* |
| scope | `1` (Full access) |
| root_folder_id | *(press Enter)* |
| service_account | *(press Enter)* |
| Edit advanced? | `n` |
| **Use web browser?** | **`n`** ← critical! |
| *(A long URL appears)* | **Open it in Chrome → sign in with Google** |
| Paste the code | *(paste the code shown after sign-in)* |
| Shared Drive? | `n` → `y` → `q` |

Test it:
```bash
rclone lsd gdrive:
```
If your Drive folders appear — you're connected ✅

---

### 🔁 Dropbox-Style Sync

Unlike simple upload/download, **Dropbox-style sync** (bisync) keeps a local folder **perfectly mirrored** with a Drive folder:

- Edit a file on Drive → it appears on your phone
- Add a file on your phone → it goes to Drive
- Delete on one side → synced to the other

To enable, open the management panel:
```bash
gsync
# Choose [4] Dropbox-style sync
```

Or edit `config.sh`:
```bash
DROPBOX_SYNC_ENABLED="true"
DROPBOX_LOCAL_ROOT="$HOME/storage/shared/DriveSync"
DROPBOX_DRIVE_ROOT="DriveSync"
```

---

### 📱 Telegram Notifications

Get alerts like this on your phone for every event:

```
☁️ UPLOAD
File: IMG_20250101.jpg
Dest: GDriveSync/Camera
2025-01-01 14:32:01
```

**Setup:**
1. Chat `@BotFather` on Telegram → `/newbot` → copy the **Token**
2. Chat `@userinfobot` → copy your **Chat ID**
3. Open `gsync` → `[5] Telegram` → enter Token & Chat ID → enable

---

### ⚙️ Daily Commands

```bash
gsync                        # Open the management panel
bash ~/gdrive-sync/start.sh  # Start the watcher
bash ~/gdrive-sync/stop.sh   # Stop the watcher
bash ~/gdrive-sync/status.sh # View status & logs
```

After reopening Termux:
```bash
gsync   # shortcut installed automatically
```

---

### 📁 Adding Sync Folders

**From the panel:** `gsync` → `[3] Manage Folders` → `[A] Add`

**Or manually in `config.sh`:**
```bash
SYNC_FOLDERS=(
  "$HOME/storage/dcim/Camera|GDriveSync/Camera|up"
  "$HOME/storage/downloads|GDriveSync/Downloads|up"
  "$HOME/storage/documents|GDriveSync/Documents|both"
  # Format: "local_path|drive_path|direction"
  # direction: up | down | both
)
```

---

### 📂 Project Structure

```
gdrive-sync/
├── install.sh         ← One-command installer from GitHub
├── config.sh          ← All settings (edit here)
├── watcher.sh         ← Core engine: watches & syncs files
├── manage.sh          ← Interactive management panel
├── start.sh           ← Start the watcher (background)
├── stop.sh            ← Stop the watcher
├── status.sh          ← View status & recent logs
├── scripts/
│   ├── logger.sh      ← Logging & phone notifications
│   └── telegram.sh    ← Telegram bot integration
└── logs/
    ├── watcher.log    ← Full operation log
    └── uploaded.txt   ← Registry of uploaded files
```

---

### ❓ Troubleshooting

| Problem | Solution |
|---|---|
| `rclone: not found` | `pkg install rclone` |
| `inotifywait: not found` | `pkg install inotify-tools` |
| Drive connection fails | `rclone config reconnect gdrive:` |
| No storage permission | `termux-setup-storage` |
| Watcher stops when phone sleeps | Exclude Termux from battery optimization |
| Bisync fails on first run | Run bisync manually from panel → it uses `--resync` once |

---

### 🔁 Auto-start with Termux

```bash
echo "bash ~/gdrive-sync/start.sh" >> ~/.bashrc
```

> ⚠️ Also disable battery optimization for Termux in your phone's settings to keep it running in the background.

---

## 🇸🇦 العربية

### ما هو GDrive Sync؟

مشروع Bash على Termux يراقب فولدرات هاتفك ويرفع الملفات الجديدة تلقائياً على **Google Drive** فور ظهورها — مع دعم المزامنة الكاملة في الاتجاهين (مثل Dropbox)، وفولدرات متعددة، وإشعارات Telegram.

لا يحتاج Root. لا يحتاج تطبيق. فقط Termux و rclone.

---

### ✨ المميزات

| الميزة | الوصف |
|---|---|
| ⚡ **اكتشاف فوري** | يكتشف الملفات الجديدة لحظياً عبر `inotifywait` |
| 📁 **فولدرات متعددة** | تتبع عدد غير محدود من الفولدرات في آنٍ واحد |
| 🔄 **مزامنة في الاتجاهين** | رفع فقط / نزيل فقط / في الاتجاهين |
| 🔁 **مزامنة كاملة (مثل Dropbox)** | مرآة كاملة بين فولدر على الهاتف وآخر على Drive |
| 📱 **إشعارات Telegram** | تنبيه فوري لكل عملية رفع أو سحب أو خطأ |
| 🛠️ **لوحة إدارة تفاعلية** | تحكم في كل شيء من قائمة — بدون تعديل ملفات |
| ⏱️ **سحب تلقائي** | يسحب التغييرات من Drive بشكل دوري |
| 🔒 **تجنب التكرار** | لا يعيد رفع ملف سبق رفعه |

---

### 🚀 التثبيت — أمر واحد

افتح **Termux** ونفّذ:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ahmed-awad26/gdrive-sync/main/install.sh)
```

سيقوم تلقائياً بـ:
1. تحديث Termux وتثبيت `inotify-tools`, `rclone`, `curl`, `git`
2. منح إذن التخزين
3. تحميل المشروع
4. إرشادك لإعداد Google Drive
5. فتح لوحة الإدارة

---

### ☁️ ربط Google Drive

هذه الخطوة الوحيدة اليدوية — تُنفَّذ مرة واحدة فقط:

```bash
rclone config
```

| السؤال | الجواب |
|---|---|
| New remote | `n` |
| Name | `gdrive` |
| Storage type | رقم **Google Drive** من القائمة |
| client_id | Enter (اتركه فارغاً) |
| client_secret | Enter (اتركه فارغاً) |
| scope | `1` (Full access) |
| root_folder_id | Enter |
| service_account | Enter |
| Edit advanced? | `n` |
| **Use web browser?** | **`n`** ← مهم جداً! |
| *(سيظهر رابط طويل)* | **افتحه في Chrome → سجّل دخول Google** |
| Paste the code | *(الصق الكود الظاهر بعد تسجيل الدخول)* |
| Shared Drive? | `n` ثم `y` ثم `q` |

اختبر:
```bash
rclone lsd gdrive:
```
إذا ظهرت فولدراتك — الربط نجح ✅

---

### 🔁 المزامنة الكاملة (مثل Dropbox)

تُبقي فولدراً على هاتفك **مرتبطاً بالكامل** بفولدر على Drive:

- تعدّل ملفاً على Drive ← يظهر على هاتفك
- تضيف ملفاً على الهاتف ← يذهب إلى Drive تلقائياً

تفعيل من لوحة الإدارة:
```bash
gsync
# اختر [4] Dropbox-style sync
```

---

### 📱 إشعارات Telegram

**الحصول على البيانات:**
1. تحدّث مع `@BotFather` → `/newbot` → انسخ الـ Token
2. تحدّث مع `@userinfobot` → انسخ الـ Chat ID

**تفعيل:**
```bash
gsync
# اختر [5] Telegram
```

---

### ⚙️ الأوامر اليومية

```bash
gsync                        # لوحة الإدارة الكاملة
bash ~/gdrive-sync/start.sh  # تشغيل
bash ~/gdrive-sync/stop.sh   # إيقاف
bash ~/gdrive-sync/status.sh # الحالة واللوق
```

---

### ❓ مشاكل شائعة

| المشكلة | الحل |
|---|---|
| `rclone: not found` | `pkg install rclone` |
| `inotifywait: not found` | `pkg install inotify-tools` |
| فشل الاتصال بـ Drive | `rclone config reconnect gdrive:` |
| لا يوجد إذن تخزين | `termux-setup-storage` |
| Termux يتوقف في الخلفية | استثنه من توفير الطاقة في إعدادات الهاتف |
| bisync فشل في أول تشغيل | شغّله يدوياً من اللوحة — سيستخدم `--resync` تلقائياً |

---

## 📜 License & Credits

```
MIT License
Copyright (c) 2025 Ahmed Awad
GitHub  : https://github.com/ahmed-awad26
Project : https://github.com/ahmed-awad26/gdrive-sync
```

---

<div align="center">

```
 █████╗ ██╗    ██╗
██╔══██╗██║    ██║
███████║██║ █╗ ██║
██╔══██║██║███╗██║
██║  ██║╚███╔███╔╝
╚═╝  ╚═╝ ╚══╝╚══╝
```

Built with ❤️ by **[Ahmed Awad](https://github.com/ahmed-awad26)**

[⭐ Star this repo](https://github.com/ahmed-awad26/gdrive-sync) · [🐛 Issues](https://github.com/ahmed-awad26/gdrive-sync/issues) · [🍴 Fork](https://github.com/ahmed-awad26/gdrive-sync/fork)

</div>
