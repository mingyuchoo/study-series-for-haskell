#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAKE_CMD="${MAKE:-make}"

cd "${PROJECT_ROOT}"

PACKAGE_NAME="$(awk '/^name:/ { print $2; exit }' package.yaml)"
VERSION="$(awk '/^version:/ { print $2; exit }' package.yaml)"
MAINTAINER="$(awk '/^maintainer:/ { print $2; exit }' package.yaml)"
LICENSE_NAME="$(awk '/^license:/ { print $2; exit }' package.yaml)"
EXECUTABLE="${PACKAGE_NAME}-exe"
PACKAGE_ID="$(printf '%s' "${PACKAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
RELEASE_DIR="${PROJECT_ROOT}/dist/release"
STAGE_DIR="${PROJECT_ROOT}/dist/package-stage"
ARCH="$(uname -m)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

run_make_release() {
  "${MAKE_CMD}" build
  "${MAKE_CMD}" test
  "${MAKE_CMD}" release
}

copy_common_files() {
  local app_root="$1"

  mkdir -p "${app_root}/bin"
  cp "${PROJECT_ROOT}/dist/bin/${EXECUTABLE}" "${app_root}/bin/${EXECUTABLE}"
  chmod +x "${app_root}/bin/${EXECUTABLE}"

  cp -R "${PROJECT_ROOT}/static" "${app_root}/static"
  cp "${PROJECT_ROOT}/README.md" "${app_root}/README.md"
  cp "${PROJECT_ROOT}/LICENSE" "${app_root}/LICENSE"
  cp "${PROJECT_ROOT}/CHANGELOG.md" "${app_root}/CHANGELOG.md"
}

package_linux() {
  require_command fpm

  rm -rf "${STAGE_DIR}"
  mkdir -p \
    "${STAGE_DIR}/opt/${PACKAGE_NAME}" \
    "${STAGE_DIR}/usr/local/bin" \
    "${STAGE_DIR}/usr/share/applications" \
    "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps" \
    "${STAGE_DIR}/package-scripts" \
    "${RELEASE_DIR}"

  copy_common_files "${STAGE_DIR}/opt/${PACKAGE_NAME}"

  {
    printf '%s\n' '#!/usr/bin/env sh'
    printf '%s\n' 'set -eu'
    printf 'APP_ROOT="/opt/%s"\n' "${PACKAGE_NAME}"
    printf 'APP_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/%s"\n' "${PACKAGE_NAME}"
    printf 'APP_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/%s"\n' "${PACKAGE_NAME}"
    printf 'APP_URL="http://localhost:8023"\n'
    printf '%s\n' 'APP_PID_FILE="${APP_DATA}/app.pid"'
    printf '%s\n' 'mkdir -p "${APP_DATA}" "${APP_LOG_DIR}"'
    printf '%s\n' 'ln -sfn "${APP_ROOT}/static" "${APP_DATA}/static"'
    printf '%s\n' 'if ! command -v xdg-open >/dev/null 2>&1; then'
    printf '%s\n' '  printf "xdg-open is required to launch the browser.\n" >&2'
    printf '%s\n' '  exit 1'
    printf '%s\n' 'fi'
    printf '%s\n' 'if ! { [ -f "${APP_PID_FILE}" ] && kill -0 "$(cat "${APP_PID_FILE}")" 2>/dev/null; }; then'
    printf '%s\n' '  (cd "${APP_DATA}" && nohup "${APP_ROOT}/bin/'"${EXECUTABLE}"'" > "${APP_LOG_DIR}/app.log" 2>&1 & echo $! > "${APP_PID_FILE}")'
    printf '%s\n' '  sleep 1'
    printf '%s\n' 'fi'
    printf '%s\n' 'exec xdg-open "${APP_URL}"'
  } > "${STAGE_DIR}/usr/local/bin/${PACKAGE_NAME}"
  chmod +x "${STAGE_DIR}/usr/local/bin/${PACKAGE_NAME}"

  cat > "${STAGE_DIR}/usr/share/applications/${PACKAGE_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${PACKAGE_NAME}
Comment=Threepenny address book
Exec=/usr/local/bin/${PACKAGE_NAME}
Icon=${PACKAGE_ID}
Terminal=false
StartupNotify=true
Categories=Office;ContactManagement;
Keywords=address;contacts;threepenny;
EOF

  cat > "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps/${PACKAGE_ID}.svg" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#1f6feb"/>
  <rect x="30" y="24" width="68" height="80" rx="8" fill="#ffffff"/>
  <rect x="42" y="42" width="44" height="8" rx="4" fill="#1f6feb"/>
  <rect x="42" y="60" width="44" height="6" rx="3" fill="#8bb8ff"/>
  <rect x="42" y="74" width="34" height="6" rx="3" fill="#8bb8ff"/>
  <circle cx="88" cy="86" r="18" fill="#2da44e"/>
  <path d="M80 86l5 5 11-12" fill="none" stroke="#ffffff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
EOF

  cat > "${STAGE_DIR}/package-scripts/after-install.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
EOF

  cat > "${STAGE_DIR}/package-scripts/after-remove.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
EOF
  chmod +x "${STAGE_DIR}/package-scripts/after-install.sh" "${STAGE_DIR}/package-scripts/after-remove.sh"

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${STAGE_DIR}/usr/share/applications/${PACKAGE_ID}.desktop"
  fi

  fpm -s dir -t deb \
    --force \
    -C "${STAGE_DIR}" \
    -n "${PACKAGE_ID}" \
    -v "${VERSION}" \
    --license "${LICENSE_NAME}" \
    --maintainer "${MAINTAINER}" \
    --description "Threepenny GUI address book" \
    --architecture native \
    --depends xdg-utils \
    --after-install "${STAGE_DIR}/package-scripts/after-install.sh" \
    --after-remove "${STAGE_DIR}/package-scripts/after-remove.sh" \
    --exclude package-scripts \
    -p "${RELEASE_DIR}/${PACKAGE_ID}_${VERSION}_linux_${ARCH}.deb" \
    .

  fpm -s dir -t rpm \
    --force \
    -C "${STAGE_DIR}" \
    -n "${PACKAGE_ID}" \
    -v "${VERSION}" \
    --license "${LICENSE_NAME}" \
    --maintainer "${MAINTAINER}" \
    --description "Threepenny GUI address book" \
    --architecture native \
    --depends xdg-utils \
    --after-install "${STAGE_DIR}/package-scripts/after-install.sh" \
    --after-remove "${STAGE_DIR}/package-scripts/after-remove.sh" \
    --exclude package-scripts \
    -p "${RELEASE_DIR}/${PACKAGE_ID}-${VERSION}-linux-${ARCH}.rpm" \
    .
}

package_macos() {
  require_command hdiutil

  local app_bundle="${STAGE_DIR}/${PACKAGE_NAME}.app"
  local contents="${app_bundle}/Contents"
  local resources="${contents}/Resources"

  rm -rf "${STAGE_DIR}"
  mkdir -p "${contents}/MacOS" "${resources}" "${RELEASE_DIR}"

  copy_common_files "${resources}"

  {
    printf '%s\n' '#!/usr/bin/env sh'
    printf '%s\n' 'set -eu'
    printf '%s\n' 'APP_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"'
    printf '%s\n' 'cd "${APP_DIR}"'
    printf 'exec ./bin/%s "$@"\n' "${EXECUTABLE}"
  } > "${contents}/MacOS/${PACKAGE_NAME}"
  chmod +x "${contents}/MacOS/${PACKAGE_NAME}"

  cat > "${contents}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${PACKAGE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.mingyuchoo.${PACKAGE_NAME}</string>
  <key>CFBundleName</key>
  <string>${PACKAGE_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
</dict>
</plist>
EOF

  hdiutil create \
    -volname "${PACKAGE_NAME} ${VERSION}" \
    -srcfolder "${app_bundle}" \
    -ov \
    -format UDZO \
    "${RELEASE_DIR}/${PACKAGE_NAME}-${VERSION}-macos-${ARCH}.dmg"
}

run_make_release

case "$(uname -s)" in
  Linux)
    package_linux
    ;;
  Darwin)
    package_macos
    ;;
  *)
    printf 'error: unsupported OS for release.sh: %s\n' "$(uname -s)" >&2
    printf 'Use scripts/release.ps1 on Windows to build the MSI package.\n' >&2
    exit 1
    ;;
esac

printf 'Release artifacts written to %s\n' "${RELEASE_DIR}"
