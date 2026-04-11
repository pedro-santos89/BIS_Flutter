; ─────────────────────────────────────────────────────────────
; Inno Setup script for BIS (BUS Information System)
; Prerequisites:
;   1. Run: flutter build windows --release
;   2. Run: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" scripts\bis_windows_installer.iss
; Output: build\BIS-Setup.exe
; ─────────────────────────────────────────────────────────────

#define MyAppName "BIS"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "BUS"
#define MyAppExeName "bis_flutter.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\build
OutputBaseFilename=BIS-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copy the entire release build output
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Copy documentation files
Source: "..\README.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "..\USAGE_MANUAL.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "..\INSTALL_WINDOWS.md"; DestDir: "{app}\docs"; Flags: ignoreversion

[Icons]
; Start Menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\README"; Filename: "{app}\docs\README.md"
Name: "{group}\Usage Manual"; Filename: "{app}\docs\USAGE_MANUAL.md"
Name: "{group}\Installation Guide"; Filename: "{app}\docs\INSTALL_WINDOWS.md"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
; Desktop shortcut (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[UninstallDelete]
; Remove docs folder and any app-created data inside the install directory
Type: filesandordirs; Name: "{app}\docs"
Type: filesandordirs; Name: "{app}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch BIS"; Flags: nowait postinstall skipifsilent
