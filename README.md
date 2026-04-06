# BIS — BUS Information System

A Flutter desktop application for managing members and registrations for the BUS organization.  
Supports **macOS** and **Windows**.

---

## Features

- **Member Registration** — register permanent members with name, email, communication preferences, and annual fee tracking
- **Daily Member Registration** — register temporary one-day members
- **Admin Dashboard** — manage members, daily members, custom tables, and users
- **Paginated Data Tables** — server-side sorting, search, and multi-select
- **CSV / PDF / JSON Export & Import** — export lists to CSV or paginated landscape PDF; import from CSV; full database backup/restore as JSON
- **Custom Tables** — create dynamic tables with custom columns (Text, Integer, Decimal, Yes/No)
- **User Management** — create admin/normal users, change passwords, toggle roles
- **Registration Reports** — view new registrations by date range with quick presets
- **Dark & Light Themes** — matching the Django-based BIS webapp
- **Bilingual (PT/EN)** — Portuguese (default) and English, switchable in the app bar
- **Text Scaling** — adjustable text size with persistent dropdown menu

---

## Quick Start (Development)

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11+)
- For **macOS**: Xcode with command-line tools
- For **Windows**: Visual Studio 2022 with "Desktop development with C++" workload

### Run from Source

```bash
git clone https://github.com/pedro-santos89/BIS_Flutter.git
cd BIS_Flutter
flutter pub get
flutter run -d macos    # or: flutter run -d windows
```

---

## Installation (macOS)

### Option A — Pre-built DMG (recommended)

1. Download `BIS-Installer.dmg` from the [Releases](https://github.com/pedro-santos89/BIS_Flutter/releases) page.
2. Open the DMG file.
3. Drag **BIS.app** into the **Applications** folder.
4. Launch BIS from Applications or Spotlight.
5. On first launch, macOS may show a security warning — right-click the app and choose **Open**, then click **Open** in the dialog.

### Option B — Build from source

```bash
cd BIS_Flutter

# Build the release app bundle
flutter build macos --release

# Create a DMG installer (optional)
./scripts/build_macos_dmg.sh
```

The `.app` bundle will be at `build/macos/Build/Products/Release/BIS.app`.  
The DMG (if built) will be at `build/BIS-Installer.dmg`.

---

## Installation (Windows)

See [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md) for detailed instructions.

### Quick summary

```powershell
cd BIS_Flutter

# Build release
flutter build windows --release

# Create installer (requires Inno Setup)
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" scripts\bis_windows_installer.iss
```

---

## Default Login

| Username | Password | Role  |
| -------- | -------- | ----- |
| `admin`  | `admin`  | Admin |

**Change the default password immediately** after first login via Admin → Users.

---

## Project Structure

```
lib/
  main.dart              # App entry point, routes, provider setup
  models.dart            # Data models (Member, DailyMember, CustomTableDef, AppUser, etc.)
  database_helper.dart   # SQLite CRUD operations (singleton)
  providers.dart         # ThemeProvider (theme/locale/text scale) + AuthProvider
  theme.dart             # Dark & light ThemeData definitions
  l10n.dart              # EN/PT translation strings
  export_helper.dart     # CSV, PDF, JSON export/import utilities
  screens/               # All UI screens (home, admin, register, lists, reports, etc.)
assets/
  fonts/                 # Bundled Rowsky + Oswald fonts
scripts/
  build_macos_dmg.sh     # macOS DMG builder script
  bis_windows_installer.iss  # Inno Setup script for Windows installer
```

---

## Tech Stack

- **Flutter** (desktop — macOS & Windows)
- **SQLite** via `sqflite` + `sqflite_common_ffi`
- **Provider** for state management
- **pdf** package for PDF generation
- **csv** + **file_picker** for CSV import/export

---

## License

Copyright © 2026 BUS. All rights reserved.
