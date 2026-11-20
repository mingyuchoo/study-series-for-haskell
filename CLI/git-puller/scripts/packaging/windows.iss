[Setup]
AppId=org.mingyuchoo.git-puller
AppName=Git Puller
AppVersion={#ReleaseVersion}
DefaultDirName={localappdata}\Programs\Git Puller
PrivilegesRequired=lowest
OutputBaseFilename=git-puller-{#ReleaseVersion}-windows-wsl-{#ReleaseArch}-setup
WizardStyle=modern
ArchitecturesAllowed={#WindowsArch}
InfoBeforeFile=requirements.txt

[Files]
Source: "bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
