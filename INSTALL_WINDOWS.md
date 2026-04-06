# Windows Installation Guide — BIS (BUS Information System)

## Option A — Pre-built Installer (Recommended)

1. Download `BIS-Setup.exe` from the [Releases](https://github.com/pedro-santos89/BIS_Flutter/releases) page.
2. Run the installer and follow the wizard.
3. The app will be installed to `C:\Program Files\BIS` by default.
4. Launch **BIS** from the Start Menu or Desktop shortcut.

---

## Option B — Build from Source

### Prerequisites

1. **Flutter SDK 3.11+**  
   Follow the [official install guide](https://docs.flutter.dev/get-started/install/windows/desktop).

2. **Visual Studio 2022** (Community edition is fine)  
   During installation, select the **"Desktop development with C++"** workload.  
   This is required by Flutter to compile Windows desktop apps.

3. **Git** — [git-scm.com](https://git-scm.com/download/win)

### Verify Flutter setup

```powershell
flutter doctor
```

Ensure `[✓] Windows Version` and `[✓] Visual Studio` both show green checkmarks.

### Build the app

```powershell
git clone https://github.com/pedro-santos89/BIS_Flutter.git
cd BIS_Flutter
flutter pub get
flutter build windows --release
```

The compiled app will be at:
```
build\windows\x64\runner\Release\
```

You can run `bis_flutter.exe` directly from that folder.

---

## Option C — Create an Installer with Inno Setup

If you want to distribute BIS as a proper Windows installer:

### Install Inno Setup

1. Download [Inno Setup 6](https://jrsoftware.org/isdl.php) and install it.
2. Make sure `ISCC.exe` is available (default: `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`).

### Build the installer

```powershell
cd BIS_Flutter

# First build the release
flutter build windows --release

# Then compile the installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" scripts\bis_windows_installer.iss
```

The installer will be created at:
```
build\BIS-Setup.exe
```

---

## Troubleshooting

### "VCRUNTIME140.dll not found"
Install the [Microsoft Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) (x64).

### App won't start / white screen
Make sure all DLL files from the `Release\` folder are present alongside the `.exe`. The Flutter build output must be kept as a complete folder — do not move just the `.exe`.

### Database location
The SQLite database (`bis.db`) is stored in the app's data directory:
```
C:\Users\<username>\AppData\Roaming\com.bus\bisFlutter\databases\
```

---

## Default Login

| Username | Password | Role  |
|----------|----------|-------|
| `admin`  | `admin`  | Admin |

**Change the default password immediately** after first login via Admin → Users.
