#ifndef TraceVersion
  #define TraceVersion "0.1.2"
#endif
#ifndef TraceMinimumWindowsVersion
  #error TraceMinimumWindowsVersion must be provided from windows/Compatibility.props by build-windows.ps1
#endif
#ifndef TraceArchitecture
  #define TraceArchitecture "x64"
#endif
#ifndef TraceSource
  #error TraceSource must point to the published application directory
#endif
#ifndef TraceOutput
  #error TraceOutput must point to the package output directory
#endif

[Setup]
AppId={{D9B1C13B-6FDC-4AE0-9B70-B2C56554CF7E}
AppName=迹 · Trace
AppVersion={#TraceVersion}
AppPublisher=Trace contributors
AppPublisherURL=https://github.com/aiyougit/trace
AppSupportURL=https://github.com/aiyougit/trace/issues
DefaultDirName={localappdata}\Programs\Trace
DefaultGroupName=迹 · Trace
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion={#TraceMinimumWindowsVersion}
#if TraceArchitecture == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
AppMutex=Local\Trace.Desktop.SingleInstance
OutputDir={#TraceOutput}
OutputBaseFilename=Trace-{#TraceVersion}-windows-{#TraceArchitecture}-setup
SetupIconFile=..\Trace.Windows\Assets\Trace.ico
UninstallDisplayIcon={app}\Trace.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
LicenseFile=..\..\LICENSE

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl,ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "其他选项："; Flags: unchecked

[Files]
Source: "{#TraceSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\迹 · Trace"; Filename: "{app}\Trace.exe"
Name: "{autodesktop}\迹 · Trace"; Filename: "{app}\Trace.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Trace.exe"; Description: "启动迹 · Trace"; Flags: nowait postinstall skipifsilent
