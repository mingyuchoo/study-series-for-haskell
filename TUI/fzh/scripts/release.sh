#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PACKAGE_NAME="fzh"
EXECUTABLE_NAME="fzh-exe"
COMMAND_NAME="fzh"
VERSION="$(sed -n 's/^version:[[:space:]]*//p' "${ROOT_DIR}/package.yaml" | head -n 1)"
LICENSE_NAME="$(sed -n 's/^license:[[:space:]]*//p' "${ROOT_DIR}/package.yaml" | head -n 1)"
RELEASE_DIR="${ROOT_DIR}/dist/release"
STAGE_DIR="${ROOT_DIR}/dist/package-root"
BUILD_DONE=0

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [target]

Targets:
  auto   Build the native installer for the current OS (default)
  linux  Build both .deb and .rpm packages
  deb    Build a Debian package
  rpm    Build an RPM package
  dmg    Build a macOS disk image
  clean  Remove dist/release and dist/package-root
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

write_app_icon() {
  local icon_path="$1"
  cat > "$icon_path" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#202124"/>
  <path d="M26 36h76v56H26z" fill="#111315" stroke="#70e1f5" stroke-width="4"/>
  <path d="M38 50l16 14-16 14" fill="none" stroke="#70e1f5" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M62 80h28" fill="none" stroke="#f7d154" stroke-width="7" stroke-linecap="round"/>
</svg>
EOF
}

write_linux_desktop_entry() {
  local desktop_path="$1"
  cat > "$desktop_path" <<EOF
[Desktop Entry]
Type=Application
Name=fzh
Comment=Terminal fuzzy finder
Exec=/usr/local/bin/fzh
Icon=fzh
Terminal=true
Categories=Utility;FileTools;
Keywords=fuzzy;finder;terminal;files;
EOF
}

write_post_install_script() {
  local script_path="$1"
  cat > "$script_path" <<'EOF'
#!/bin/sh
set -e

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
EOF
}

build_release() {
  if [ "$BUILD_DONE" -eq 1 ]; then
    return
  fi

  cd "$ROOT_DIR"
  make release
  BUILD_DONE=1
}

local_install_root() {
  cd "$ROOT_DIR"
  stack path --local-install-root
}

prepare_unix_stage() {
  local bin_path
  bin_path="$(local_install_root)/bin/${EXECUTABLE_NAME}"

  if [ ! -x "$bin_path" ]; then
    echo "Built executable not found: $bin_path" >&2
    exit 1
  fi

  rm -rf "$STAGE_DIR"
  install -d "$STAGE_DIR/usr/local/bin"
  install -d "$STAGE_DIR/usr/local/share/doc/$PACKAGE_NAME"
  install -d "$STAGE_DIR/usr/share/applications"
  install -d "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps"
  install -m 755 "$bin_path" "$STAGE_DIR/usr/local/bin/$COMMAND_NAME"
  install -m 644 "$ROOT_DIR/README.md" "$STAGE_DIR/usr/local/share/doc/$PACKAGE_NAME/README.md"
  install -m 644 "$ROOT_DIR/LICENSE" "$STAGE_DIR/usr/local/share/doc/$PACKAGE_NAME/LICENSE"
  write_linux_desktop_entry "$STAGE_DIR/usr/share/applications/$PACKAGE_NAME.desktop"
  write_app_icon "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps/$PACKAGE_NAME.svg"

  if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$STAGE_DIR/usr/share/applications/$PACKAGE_NAME.desktop"
  fi
}

build_deb() {
  require_command fpm
  require_command dpkg-deb
  build_release
  prepare_unix_stage

  local arch package_path
  arch="$(dpkg --print-architecture 2>/dev/null || echo "$(uname -m)")"
  package_path="$RELEASE_DIR/${PACKAGE_NAME}_${VERSION}_${arch}.deb"
  post_install_script="${ROOT_DIR}/dist/${PACKAGE_NAME}-post-install.sh"
  write_post_install_script "$post_install_script"

  mkdir -p "$RELEASE_DIR"
  fpm --force \
    -s dir \
    -t deb \
    -n "$PACKAGE_NAME" \
    -v "$VERSION" \
    --license "$LICENSE_NAME" \
    --description "Terminal fuzzy finder written in Haskell" \
    --url "https://github.com/mingyuchoo/fzh" \
    --architecture "$arch" \
    --after-install "$post_install_script" \
    --after-remove "$post_install_script" \
    --package "$package_path" \
    -C "$STAGE_DIR" \
    usr/local/bin/"$COMMAND_NAME" \
    usr/local/share/doc/"$PACKAGE_NAME"/README.md \
    usr/local/share/doc/"$PACKAGE_NAME"/LICENSE \
    usr/share/applications/"$PACKAGE_NAME".desktop \
    usr/share/icons/hicolor/scalable/apps/"$PACKAGE_NAME".svg

  dpkg-deb --info "$package_path" >/dev/null
  echo "Created $package_path"
}

build_rpm() {
  require_command fpm
  require_command rpmbuild
  require_command rpm2cpio
  require_command cpio
  build_release
  prepare_unix_stage

  local arch package_path
  arch="$(uname -m)"
  package_path="$RELEASE_DIR/${PACKAGE_NAME}-${VERSION}-1.${arch}.rpm"
  post_install_script="${ROOT_DIR}/dist/${PACKAGE_NAME}-post-install.sh"
  write_post_install_script "$post_install_script"

  mkdir -p "$RELEASE_DIR"
  fpm --force \
    -s dir \
    -t rpm \
    -n "$PACKAGE_NAME" \
    -v "$VERSION" \
    --iteration 1 \
    --license "$LICENSE_NAME" \
    --description "Terminal fuzzy finder written in Haskell" \
    --url "https://github.com/mingyuchoo/fzh" \
    --architecture "$arch" \
    --after-install "$post_install_script" \
    --after-remove "$post_install_script" \
    --package "$package_path" \
    -C "$STAGE_DIR" \
    usr/local/bin/"$COMMAND_NAME" \
    usr/local/share/doc/"$PACKAGE_NAME"/README.md \
    usr/local/share/doc/"$PACKAGE_NAME"/LICENSE \
    usr/share/applications/"$PACKAGE_NAME".desktop \
    usr/share/icons/hicolor/scalable/apps/"$PACKAGE_NAME".svg

  rpm2cpio "$package_path" | cpio -t >/dev/null 2>&1
  echo "Created $package_path"
}

build_dmg() {
  require_command hdiutil
  build_release

  local bin_path dmg_root app_root dmg_path launcher_path plist_path
  bin_path="$(local_install_root)/bin/${EXECUTABLE_NAME}"
  dmg_root="${ROOT_DIR}/dist/${PACKAGE_NAME}-${VERSION}-macos"
  app_root="$dmg_root/fzh.app"
  dmg_path="$RELEASE_DIR/${PACKAGE_NAME}-${VERSION}.dmg"
  launcher_path="$app_root/Contents/MacOS/fzh"
  plist_path="$app_root/Contents/Info.plist"

  if [ ! -x "$bin_path" ]; then
    echo "Built executable not found: $bin_path" >&2
    exit 1
  fi

  rm -rf "$dmg_root" "$dmg_path"
  install -d "$app_root/Contents/MacOS"
  install -d "$app_root/Contents/Resources"
  install -m 755 "$bin_path" "$app_root/Contents/Resources/$COMMAND_NAME"
  install -m 644 "$ROOT_DIR/README.md" "$dmg_root/README.md"
  install -m 644 "$ROOT_DIR/LICENSE" "$dmg_root/LICENSE"
  write_app_icon "$app_root/Contents/Resources/fzh.svg"
  cat > "$launcher_path" <<'EOF'
#!/bin/sh
set -e

APP_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BIN="$APP_DIR/Resources/fzh"

osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script quoted form of "$BIN"
end tell
APPLESCRIPT
EOF
  chmod +x "$launcher_path"
  cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>fzh</string>
  <key>CFBundleIdentifier</key>
  <string>com.mingyuchoo.fzh</string>
  <key>CFBundleName</key>
  <string>fzh</string>
  <key>CFBundleDisplayName</key>
  <string>fzh</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
</dict>
</plist>
EOF
  ln -s /Applications "$dmg_root/Applications"
  mkdir -p "$RELEASE_DIR"

  hdiutil create \
    -volname "${PACKAGE_NAME} ${VERSION}" \
    -srcfolder "$dmg_root" \
    -ov \
    -format UDZO \
    "$dmg_path"

  echo "Created $dmg_path"
}

target="${1:-auto}"

case "$target" in
  auto)
    case "$(uname -s)" in
      Linux) build_deb; build_rpm ;;
      Darwin) build_dmg ;;
      *) echo "Unsupported OS for release.sh: $(uname -s)" >&2; exit 1 ;;
    esac
    ;;
  linux) build_deb; build_rpm ;;
  deb) build_deb ;;
  rpm) build_rpm ;;
  dmg) build_dmg ;;
  clean) rm -rf "$RELEASE_DIR" "$STAGE_DIR" ;;
  -h|--help|help) usage ;;
  *) echo "Unknown target: $target" >&2; usage >&2; exit 2 ;;
esac
