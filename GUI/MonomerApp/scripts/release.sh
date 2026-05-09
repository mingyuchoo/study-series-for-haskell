#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="${APP_NAME:-MonomerApp}"
PACKAGE_NAME="${PACKAGE_NAME:-monomerapp}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-app}"
VERSION="${VERSION:-$(awk '/^version:/ {print $2; exit}' "${PROJECT_ROOT}/package.yaml")}"
STACK_BIN="${STACK:-stack}"
MAKE_BIN="${MAKE:-make}"

DIST_DIR="${PROJECT_ROOT}/dist/release"
WORK_DIR="${DIST_DIR}/work"
PAYLOAD_DIR="${WORK_DIR}/payload"
BIN_DIR="${PAYLOAD_DIR}/bin"

usage() {
  cat <<EOF
Usage: scripts/release.sh

Builds and tests the app through the Makefile, then creates a native installer
for the current host OS:
  Linux:  ${PACKAGE_NAME}_${VERSION}_<arch>.deb and ${PACKAGE_NAME}-${VERSION}-1.<arch>.rpm
  macOS:  ${APP_NAME}-${VERSION}.dmg

Required platform tools:
  Linux:  dpkg-deb and rpmbuild
  macOS:  hdiutil
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

run_make() {
  local target=$1
  printf '\n==> make %s\n' "${target}"
  "${MAKE_BIN}" -C "${PROJECT_ROOT}" "${target}"
}

prepare_binary() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${BIN_DIR}"

  printf '\n==> stack install %s:exe:%s\n' "${APP_NAME}" "${EXECUTABLE_NAME}"
  "${STACK_BIN}" install "${APP_NAME}:exe:${EXECUTABLE_NAME}" --local-bin-path "${BIN_DIR}"

  if [ ! -x "${BIN_DIR}/${EXECUTABLE_NAME}" ]; then
    printf 'Expected executable was not created: %s\n' "${BIN_DIR}/${EXECUTABLE_NAME}" >&2
    exit 1
  fi
}

copy_assets() {
  local target=$1
  mkdir -p "${target}"
  cp -R "${PROJECT_ROOT}/assets" "${target}/assets"
}

linux_arch_deb() {
  case "$(uname -m)" in
    x86_64) printf 'amd64' ;;
    aarch64 | arm64) printf 'arm64' ;;
    armv7l) printf 'armhf' ;;
    *) uname -m ;;
  esac
}

linux_arch_rpm() {
  case "$(uname -m)" in
    x86_64) printf 'x86_64' ;;
    aarch64 | arm64) printf 'aarch64' ;;
    armv7l) printf 'armv7hl' ;;
    *) uname -m ;;
  esac
}

prepare_linux_root() {
  local root=$1
  rm -rf "${root}"
  mkdir -p \
    "${root}/opt/${APP_NAME}/bin" \
    "${root}/usr/bin" \
    "${root}/usr/share/applications" \
    "${root}/usr/share/icons/hicolor/512x512/apps"

  cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${root}/opt/${APP_NAME}/bin/${EXECUTABLE_NAME}"
  copy_assets "${root}/opt/${APP_NAME}"
  cp "${PROJECT_ROOT}/assets/images/icon.png" "${root}/usr/share/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png"

  cat >"${root}/usr/bin/${PACKAGE_NAME}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd /opt/${APP_NAME}
exec ./bin/${EXECUTABLE_NAME} "\$@"
EOF
  chmod 0755 "${root}/usr/bin/${PACKAGE_NAME}"

  cat >"${root}/usr/share/applications/${PACKAGE_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=${APP_NAME} Monomer desktop application
Exec=${PACKAGE_NAME}
Icon=${PACKAGE_NAME}
Terminal=false
Categories=Utility;
StartupNotify=true
EOF
}

build_deb() {
  require_command dpkg-deb

  local arch root deb_path
  arch="$(linux_arch_deb)"
  root="${WORK_DIR}/deb-root"
  deb_path="${DIST_DIR}/${PACKAGE_NAME}_${VERSION}_${arch}.deb"

  prepare_linux_root "${root}"
  mkdir -p "${root}/DEBIAN"
  cat >"${root}/DEBIAN/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${arch}
Maintainer: example@example.com
Depends: libsdl2-2.0-0, libglew2.2 | libglew2.1 | libglew2.0
Description: ${APP_NAME} Monomer desktop application
 A desktop application built with Haskell and Monomer.
EOF

  find "${root}" -type d -exec chmod 0755 {} +
  dpkg-deb --build --root-owner-group "${root}" "${deb_path}"
  printf 'Created %s\n' "${deb_path}"
}

build_rpm() {
  require_command rpmbuild

  local arch rpm_top buildroot spec rpm_path
  arch="$(linux_arch_rpm)"
  rpm_top="${WORK_DIR}/rpmbuild"
  buildroot="${rpm_top}/BUILDROOT/${PACKAGE_NAME}-${VERSION}-1.${arch}"
  spec="${rpm_top}/SPECS/${PACKAGE_NAME}.spec"

  mkdir -p "${rpm_top}/"{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  prepare_linux_root "${buildroot}"

  cat >"${spec}" <<EOF
Name: ${PACKAGE_NAME}
Version: ${VERSION}
Release: 1%{?dist}
Summary: ${APP_NAME} Monomer desktop application
License: BSD-3-Clause
Requires: SDL2
Requires: glew

%description
A desktop application built with Haskell and Monomer.

%install
mkdir -p %{buildroot}
cp -a ${buildroot}/* %{buildroot}/

%files
/opt/${APP_NAME}
/usr/bin/${PACKAGE_NAME}
/usr/share/applications/${PACKAGE_NAME}.desktop
/usr/share/icons/hicolor/512x512/apps/${PACKAGE_NAME}.png
EOF

  rpmbuild --define "_topdir ${rpm_top}" --define "_build_id_links none" -bb "${spec}"
  rpm_path="$(find "${rpm_top}/RPMS" -name '*.rpm' -type f | head -n 1)"
  if [ -z "${rpm_path}" ]; then
    printf 'RPM build completed but no .rpm file was found.\n' >&2
    exit 1
  fi
  cp "${rpm_path}" "${DIST_DIR}/"
  printf 'Created %s/%s\n' "${DIST_DIR}" "$(basename "${rpm_path}")"
}

build_linux() {
  build_deb
  build_rpm
}

build_macos() {
  require_command hdiutil

  local app_dir contents macos resources plist dmg_path
  app_dir="${WORK_DIR}/${APP_NAME}.app"
  contents="${app_dir}/Contents"
  macos="${contents}/MacOS"
  resources="${contents}/Resources"
  plist="${contents}/Info.plist"
  dmg_path="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

  rm -rf "${app_dir}" "${dmg_path}"
  mkdir -p "${macos}" "${resources}/bin"
  cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${resources}/bin/${EXECUTABLE_NAME}"
  copy_assets "${resources}"

  cat >"${macos}/${APP_NAME}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")/.." && pwd)"
cd "\${APP_DIR}/Resources"
exec ./bin/${EXECUTABLE_NAME} "\$@"
EOF
  chmod 0755 "${macos}/${APP_NAME}"

  cat >"${plist}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.example.${PACKAGE_NAME}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <string>YES</string>
  <key>NSHighResolutionCapable</key>
  <string>YES</string>
</dict>
</plist>
EOF

  hdiutil create -volname "${APP_NAME}" -srcfolder "${app_dir}" -ov -format UDZO "${dmg_path}"
  printf 'Created %s\n' "${dmg_path}"
}

main() {
  case "${1:-}" in
    -h | --help | help)
      usage
      exit 0
      ;;
    "")
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac

  mkdir -p "${DIST_DIR}"
  run_make build
  run_make test
  prepare_binary

  case "$(uname -s)" in
    Linux) build_linux ;;
    Darwin) build_macos ;;
    *)
      printf 'Unsupported host OS for release.sh: %s\n' "$(uname -s)" >&2
      exit 1
      ;;
  esac
}

main "$@"
