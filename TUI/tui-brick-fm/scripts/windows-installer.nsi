Unicode true
!include "MUI2.nsh"

Name "hfm"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\hfm"
InstallDirRegKey HKCU "Software\hfm" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}"
VIAddVersionKey "ProductName" "hfm"
VIAddVersionKey "FileDescription" "hfm terminal file manager installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Mingyu Choo"

!insertmacro MUI_PAGE_LICENSE "${ROOT_DIR}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "hfm"
  SetOutPath "$INSTDIR"
  File /oname=hfm.exe "${BIN_DIR}\hfm.exe"
  File "${ROOT_DIR}\README.md"
  File "${ROOT_DIR}\LICENSE"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateDirectory "$SMPROGRAMS\hfm"
  CreateShortcut "$SMPROGRAMS\hfm\hfm.lnk" "$INSTDIR\hfm.exe"
  CreateShortcut "$SMPROGRAMS\hfm\Uninstall hfm.lnk" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\hfm" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm" "DisplayName" "hfm"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm" "UninstallString" '$\"$INSTDIR\uninstall.exe$\"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\hfm.exe"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\hfm\hfm.lnk"
  Delete "$SMPROGRAMS\hfm\Uninstall hfm.lnk"
  RMDir "$SMPROGRAMS\hfm"
  DeleteRegKey HKCU "Software\hfm"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\hfm"
SectionEnd
