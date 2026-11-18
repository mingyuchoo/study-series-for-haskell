[Setup]
AppId=io.github.mingyuchoo.tto
AppName=tto
AppVersion={#ReleaseVersion}
AppPublisher=Mingyu Choo
AppPublisherURL=https://github.com/mingyuchoo/tto
DefaultDirName={localappdata}\Programs\tto
DefaultGroupName=tto
PrivilegesRequired=lowest
ArchitecturesAllowed={#ReleaseArchitecture}
ArchitecturesInstallIn64BitMode={#ReleaseArchitecture}
MinVersion=10.0.22000
LicenseFile={#BundleDir}\share\doc\tto\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=tto
UninstallDisplayIcon={app}\bin\tto.exe

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\tto"; Filename: "{app}\bin\tto.exe"; WorkingDir: "{userprofile}"
Name: "{group}\Uninstall tto"; Filename: "{uninstallexe}"
