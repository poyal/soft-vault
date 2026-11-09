#ifndef Payload
  #error Payload must point to the verified SoftVault-Windows package
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif

[Setup]
AppId=SoftVault
AppName=Soft Vault
AppVersion={#AppVersion}
AppPublisher=Soft Vault
AppPublisherURL=https://github.com/poyal/soft-vault
DefaultDirName={localappdata}\SoftVault
DefaultGroupName=Soft Vault
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
AllowNoIcons=yes
WizardStyle=modern
OutputBaseFilename=SoftVault-{#AppVersion}-Windows-x64-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/normal
SolidCompression=yes
UninstallDisplayIcon={app}\bin\soft_vault.exe
; The updater atomically replaces bin. Its sibling uninstaller must survive.
UninstallFilesDir={app}\uninstall
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#Payload}\app\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Payload}\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Soft Vault"; Filename: "{app}\bin\soft_vault.exe"; WorkingDir: "{app}\bin"
Name: "{autodesktop}\Soft Vault"; Filename: "{app}\bin\soft_vault.exe"; WorkingDir: "{app}\bin"; Tasks: desktopicon

[Run]
Filename: "{app}\bin\soft_vault.exe"; Description: "{cm:LaunchProgram,Soft Vault}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; These contain application binaries only. Catalogs and videos live elsewhere.
Type: filesandordirs; Name: "{app}\bin"
Type: filesandordirs; Name: "{app}\bin.previous"
Type: filesandordirs; Name: "{app}\bin.update-stage"
