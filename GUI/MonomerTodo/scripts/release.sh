#!/usr/bin/env bash
set -euo pipefail

APP_ID="monomertodo"
APP_NAME="MonomerTodo"
EXE_NAME="app"
VERSION="${VERSION:-0.1.0}"
MAINTAINER="${MAINTAINER:-example@example.com}"
VENDOR="${VENDOR:-MonomerTodo}"
DESCRIPTION="${DESCRIPTION:-Monomer Todo GUI application}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build/release"

usage() {
  cat <<EOF
Usage: $(basename "$0") [linux|macos]

Build native installer artifacts for the current host:
  linux   -> ${APP_NAME}-${VERSION}-<arch>.deb and .rpm
  macos   -> ${APP_NAME}-${VERSION}.dmg

Environment overrides:
  VERSION       Package version. Default: ${VERSION}
  MAINTAINER    Package maintainer. Default: ${MAINTAINER}
  VENDOR        Package vendor/manufacturer. Default: ${VENDOR}
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

host_target() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    *) echo "error: unsupported host OS: $(uname -s)" >&2; exit 1 ;;
  esac
}

package_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "x86_64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) uname -m ;;
  esac
}

deb_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) uname -m ;;
  esac
}

stack_binary() {
  local install_root
  install_root="$(stack path --local-install-root)"
  local suffix=""
  if [[ "$(uname -s)" == "MINGW"* || "$(uname -s)" == "MSYS"* || "$(uname -s)" == "CYGWIN"* ]]; then
    suffix=".exe"
  fi
  local binary="${install_root}/bin/${EXE_NAME}${suffix}"
  if [[ ! -f "${binary}" ]]; then
    echo "error: built executable not found: ${binary}" >&2
    exit 1
  fi
  printf '%s\n' "${binary}"
}

build_app() {
  require_command stack
  echo "Building ${APP_NAME} with Stack..."
  (cd "${ROOT_DIR}" && stack build)
}

prepare_dist() {
  rm -rf "${BUILD_DIR}"
  mkdir -p "${DIST_DIR}" "${BUILD_DIR}"
}

linux_runtime_deps_deb() {
  cat <<EOF
libsdl2-2.0-0
libglew2.2
libsqlite3-0
libgl1
EOF
}

linux_runtime_deps_rpm() {
  cat <<EOF
SDL2
glew
sqlite-libs
libglvnd-glx
EOF
}

build_linux() {
  require_command fpm
  build_app
  prepare_dist

  local rpm_arch deb_pkg_arch binary stage package_root desktop_dir icon_dir wrapper_dir app_dir
  local maint_dir after_install after_remove
  rpm_arch="$(package_arch)"
  deb_pkg_arch="$(deb_arch)"
  binary="$(stack_binary)"
  stage="${BUILD_DIR}/linux"
  package_root="${stage}/pkgroot"
  maint_dir="${stage}/maintainer-scripts"
  after_install="${maint_dir}/after-install.sh"
  after_remove="${maint_dir}/after-remove.sh"
  app_dir="${package_root}/opt/${APP_ID}"
  wrapper_dir="${package_root}/usr/bin"
  desktop_dir="${package_root}/usr/share/applications"
  icon_dir="${package_root}/usr/share/icons/hicolor/512x512/apps"

  mkdir -p "${app_dir}/bin" "${app_dir}/assets" "${wrapper_dir}" "${desktop_dir}" "${icon_dir}" "${maint_dir}"
  cp "${binary}" "${app_dir}/bin/${APP_NAME}"
  cp -R "${ROOT_DIR}/assets/." "${app_dir}/assets/"
  cp "${ROOT_DIR}/assets/images/icon.png" "${icon_dir}/${APP_ID}.png"

  cat >"${wrapper_dir}/${APP_ID}" <<EOF
#!/usr/bin/env bash
cd /opt/${APP_ID}
exec /opt/${APP_ID}/bin/${APP_NAME} "\$@"
EOF
  chmod 0755 "${wrapper_dir}/${APP_ID}" "${app_dir}/bin/${APP_NAME}"

  cat >"${desktop_dir}/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
GenericName=Todo List
Comment=${DESCRIPTION}
Exec=${APP_ID}
Icon=${APP_ID}
Terminal=false
Categories=Office;ProjectManagement;
Keywords=Todo;Tasks;Monomer;
StartupNotify=true
StartupWMClass=${APP_NAME}
EOF

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "${desktop_dir}/${APP_ID}.desktop"
  fi

  cat >"${after_install}" <<'EOF'
#!/usr/bin/env bash
set -e

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
EOF

  cat >"${after_remove}" <<'EOF'
#!/usr/bin/env bash
set -e

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
EOF

  chmod 0755 "${after_install}" "${after_remove}"

  local deb_args=()
  while IFS= read -r dep; do
    [[ -n "${dep}" ]] && deb_args+=(--depends "${dep}")
  done < <(linux_runtime_deps_deb)

  local rpm_args=()
  while IFS= read -r dep; do
    [[ -n "${dep}" ]] && rpm_args+=(--depends "${dep}")
  done < <(linux_runtime_deps_rpm)

  rm -f \
    "${DIST_DIR}/${APP_NAME}-${VERSION}-${deb_pkg_arch}.deb" \
    "${DIST_DIR}/${APP_NAME}-${VERSION}-${rpm_arch}.rpm"

  echo "Creating Debian package..."
  fpm -s dir -t deb \
    -n "${APP_ID}" \
    -v "${VERSION}" \
    --architecture "${deb_pkg_arch}" \
    --maintainer "${MAINTAINER}" \
    --vendor "${VENDOR}" \
    --license "BSD-3-Clause" \
    --description "${DESCRIPTION}" \
    --after-install "${after_install}" \
    --after-remove "${after_remove}" \
    "${deb_args[@]}" \
    -C "${package_root}" \
    -p "${DIST_DIR}/${APP_NAME}-${VERSION}-${deb_pkg_arch}.deb" \
    .

  echo "Creating RPM package..."
  fpm -s dir -t rpm \
    -n "${APP_ID}" \
    -v "${VERSION}" \
    --architecture "${rpm_arch}" \
    --maintainer "${MAINTAINER}" \
    --vendor "${VENDOR}" \
    --license "BSD-3-Clause" \
    --description "${DESCRIPTION}" \
    --after-install "${after_install}" \
    --after-remove "${after_remove}" \
    "${rpm_args[@]}" \
    -C "${package_root}" \
    -p "${DIST_DIR}/${APP_NAME}-${VERSION}-${rpm_arch}.rpm" \
    .

  echo "Linux release artifacts written to ${DIST_DIR}"
}

create_icns_if_possible() {
  local source_png="$1"
  local output_icns="$2"
  local iconset="${BUILD_DIR}/${APP_NAME}.iconset"

  if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "${iconset}"
  sips -z 16 16 "${source_png}" --out "${iconset}/icon_16x16.png" >/dev/null
  sips -z 32 32 "${source_png}" --out "${iconset}/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "${source_png}" --out "${iconset}/icon_32x32.png" >/dev/null
  sips -z 64 64 "${source_png}" --out "${iconset}/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "${source_png}" --out "${iconset}/icon_128x128.png" >/dev/null
  sips -z 256 256 "${source_png}" --out "${iconset}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "${source_png}" --out "${iconset}/icon_256x256.png" >/dev/null
  sips -z 512 512 "${source_png}" --out "${iconset}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "${source_png}" --out "${iconset}/icon_512x512.png" >/dev/null
  cp "${source_png}" "${iconset}/icon_512x512@2x.png"
  iconutil -c icns "${iconset}" -o "${output_icns}"
}

build_macos() {
  require_command hdiutil
  build_app
  prepare_dist

  local binary app_bundle contents macos_dir resources_dir app_payload dmg_root
  binary="$(stack_binary)"
  app_bundle="${BUILD_DIR}/${APP_NAME}.app"
  contents="${app_bundle}/Contents"
  macos_dir="${contents}/MacOS"
  resources_dir="${contents}/Resources"
  app_payload="${resources_dir}/app"
  dmg_root="${BUILD_DIR}/dmg"

  mkdir -p "${macos_dir}" "${app_payload}/bin" "${app_payload}/assets" "${dmg_root}"
  cp "${binary}" "${app_payload}/bin/${APP_NAME}-bin"
  cp -R "${ROOT_DIR}/assets/." "${app_payload}/assets/"
  chmod 0755 "${app_payload}/bin/${APP_NAME}-bin"

  cat >"${macos_dir}/${APP_NAME}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="\$(cd "\$(dirname "\$0")/../Resources/app" && pwd)"
cd "\${APP_DIR}"
exec "\${APP_DIR}/bin/${APP_NAME}-bin" "\$@"
EOF
  chmod 0755 "${macos_dir}/${APP_NAME}"

  create_icns_if_possible "${ROOT_DIR}/assets/images/icon.png" "${resources_dir}/${APP_NAME}.icns"

  cat >"${contents}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.example.${APP_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
EOF
  if [[ -f "${resources_dir}/${APP_NAME}.icns" ]]; then
    cat >>"${contents}/Info.plist" <<EOF
  <key>CFBundleIconFile</key>
  <string>${APP_NAME}</string>
EOF
  fi
  cat >>"${contents}/Info.plist" <<EOF
</dict>
</plist>
EOF

  cp -R "${app_bundle}" "${dmg_root}/"
  ln -s /Applications "${dmg_root}/Applications"

  rm -f "${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
  hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${dmg_root}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

  echo "macOS release artifact written to ${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
}

target="${1:-$(host_target)}"
case "${target}" in
  -h | --help | help) usage ;;
  linux) build_linux ;;
  macos | darwin) build_macos ;;
  *) echo "error: unknown target: ${target}" >&2; usage; exit 1 ;;
esac
