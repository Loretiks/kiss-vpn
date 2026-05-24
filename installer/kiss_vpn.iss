; Inno Setup script for Kiss VPN.
;
; Build via scripts\build.ps1 (which calls iscc), or manually:
;   "C:\Program Files (x86)\Inno Setup 6\iscc.exe" installer\kiss_vpn.iss

#define MyAppName        "Kiss VPN"
#define MyAppVersion     "0.1.5"
#define MyAppPublisher   "kissmain.ru"
#define MyAppURL         "https://kissmain.ru"
#define MyAppExeName     "kiss_vpn.exe"
#define MyAppHelperName  "KissVPNHelper.exe"
#define MyAppCoreName    "KissVPNCore.exe"
#define MyServiceName    "KissVPNHelper"
#define MyAppCopyright   "by melanholy (t.me/m3lanh0lyy) for kissmain.ru"

[Setup]
AppId={{9B7E6C1A-1B11-4F44-8CE7-9C9D6B83C7E2}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=KissVPN-Setup-{#MyAppVersion}
OutputDir=..\dist\installer
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\kiss_vpn\windows\runner\resources\app_icon.ico
DisableWelcomePage=no
LicenseFile=
WizardImageStretch=no
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoCopyright={#MyAppCopyright}
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon";    Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart";      Description: "Launch Kiss VPN with Windows"; GroupDescription: "Startup"; Flags: unchecked
Name: "urlprotocol";    Description: "Register kissvpn:// links"; GroupDescription: "Integrations"

[Files]
Source: "..\dist\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; URL handler kissvpn://
Root: HKLM; Subkey: "Software\Classes\kissvpn"; ValueType: string; ValueName: ""; ValueData: "URL:Kiss VPN Protocol"; Tasks: urlprotocol; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\Classes\kissvpn"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: urlprotocol
Root: HKLM; Subkey: "Software\Classes\kissvpn\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"",0"; Tasks: urlprotocol
Root: HKLM; Subkey: "Software\Classes\kissvpn\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: urlprotocol

; Autostart with Windows
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "KissVPN"; ValueData: """{app}\{#MyAppExeName}"" --autostart"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppHelperName}"; Parameters: "install"; StatusMsg: "Installing helper service…"; Flags: runhidden waituntilterminated; BeforeInstall: StopHelperService
Filename: "{app}\{#MyAppExeName}";    Description: "Launch {#MyAppName}";        Flags: nowait postinstall skipifsilent unchecked

[UninstallRun]
Filename: "{app}\{#MyAppHelperName}"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveHelperService"

[Code]
procedure StopHelperService;
var
  ResultCode: Integer;
begin
  // Try to stop a previously installed service before we copy new files.
  // Failure is fine (service may not exist on a fresh install).
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#MyServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function InitializeUninstall(): Boolean;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#MyServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
