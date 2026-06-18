; ============================================================
; installer.iss - 由 build_release.ps1 自动生成
; 重新发布前请检查 AppId / 版权 / 图标等
; ============================================================
[Setup]
AppId={{A8C2E0F1-3B4D-4E5F-9A0B-1C2D3E4F5A6B}
AppName=PixelVault
AppVersion=1.0.1
AppPublisher=PixelVault
AppPublisherURL=https://example.com
AppSupportURL=https://example.com
DefaultDirName={autopf}\PixelVault
DefaultGroupName=PixelVault
AllowNoIcons=yes
OutputDir=E:\\flutter\\PicGuide\\dist
OutputBaseFilename=PixelVault-1.0.1-win-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\pixelvault.exe

[Files]
Source: "E:\\flutter\\PicGuide\\build\\windows\\x64\\runner\\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\PixelVault"; Filename: "{app}\pixelvault.exe"
Name: "{group}\PixelVault 使用手册"; Filename: "{app}\USER_MANUAL.md"
Name: "{group}\卸载 PixelVault"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\pixelvault.exe"; Description: "{cm:LaunchProgram,PixelVault}"; \
    Flags: nowait postinstall skipifsilent
