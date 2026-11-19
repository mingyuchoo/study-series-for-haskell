#!/usr/bin/env bash

set -euo pipefail
umask 022

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$project_root/dist/release"
package_format=all

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: scripts/release.sh [--package all|deb|rpm] [--output-dir PATH]' \
    'Formats, lints, builds, tests and creates a native release.' \
    'Linux: tar.gz + deb/rpm (default: both). macOS: tar.gz + pkg.' \
    'Relative output paths are resolved from the calling directory.'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --package)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--package requires all, deb or rpm.'
      package_format="$2"
      shift 2
      ;;
    --output-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--output-dir requires a path.'
      output_dir="$2"
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

case "$package_format" in
  all|deb|rpm) ;;
  *) fail "Unsupported package format: $package_format" ;;
esac

case "$output_dir" in
  /*) ;;
  *) output_dir="$PWD/$output_dir" ;;
esac

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Required tool not found: $1. See README.md for release prerequisites."
}

for tool in stack fourmolu hlint tar awk find mktemp; do
  require_tool "$tool"
done

system="$(uname -s)"
case "$system" in
  Linux)
    platform=linux
    require_tool sha256sum
    if [ "$package_format" != rpm ]; then
      require_tool dpkg-deb
      require_tool dpkg-shlibdeps
    fi
    if [ "$package_format" != deb ]; then
      require_tool rpmbuild
    fi
    ;;
  Darwin)
    platform=macos
    [ "$package_format" = all ] || fail '--package is only supported on Linux.'
    for tool in pkgbuild dylibbundler codesign shasum; do
      require_tool "$tool"
    done
    ;;
  *) fail "Unsupported operating system: $system. Use release.ps1 on Windows 11." ;;
esac

cd -- "$project_root"
version="$(awk '$1 == "version:" { print $2; exit }' package.yaml)"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || fail 'package.yaml must contain a numeric version.'

run_step() {
  local label="$1"
  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

run_step 'Formatting' find apps packages test Setup.hs -type d -name .stack-work -prune -o -type f -name '*.hs' \
  -exec fourmolu --mode inplace {} +
run_step 'Linting' hlint apps packages test Setup.hs
run_step 'Building' stack build --test --no-run-tests --ghc-options=-O2
run_step 'Testing' stack test --ghc-options=-O2

target="$(stack exec -- ghc --print-target-platform)"
case "$platform:$target" in
  linux:x86_64-*-linux*) architecture=x86_64; deb_architecture=amd64 ;;
  linux:aarch64-*-linux*) architecture=aarch64; deb_architecture=arm64 ;;
  macos:x86_64-*-darwin*) architecture=x86_64 ;;
  macos:aarch64-*-darwin*) architecture=arm64 ;;
  *) fail "Unsupported compiler target: $target on $platform" ;;
esac

install_root="$(stack path --local-install-root)"
binary="$install_root/bin/tto-exe"
[ -x "$binary" ] || fail "Built executable not found: $binary"

work_dir="$(mktemp -d /tmp/tto-release.XXXXXX)"
publication_directory=''
lock_directory=''
cleanup() {
  if [ -n "$publication_directory" ]; then
    rm -rf -- "$publication_directory"
  fi
  if [ -n "$lock_directory" ]; then
    rmdir -- "$lock_directory"
  fi
  rm -rf -- "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

artifact_name="tto-$version-$platform-$architecture"
bundle="$work_dir/$artifact_name"
artifacts="$work_dir/artifacts"
mkdir -p "$bundle/bin" "$bundle/share/tto/config" "$bundle/share/doc/tto" "$artifacts"

run_step 'Bundling executable' install -m 755 "$binary" "$bundle/bin/tto"
cp config/*.yaml "$bundle/share/tto/config/"
cp LICENSE README.md CHANGELOG.md "$bundle/share/doc/tto/"
cat > "$bundle/share/doc/tto/INSTALL.txt" <<'EOF'
Run bin/tto in an interactive terminal with a UTF-8 locale.
Keep the bundle directories together when using the archive.
Linux archives require compatible system libraries; prefer deb/rpm packages.
Configuration examples are in share/tto/config.
Copy selected YAML files to ~/.config/tto to customize the application.
User configuration and todos.db are stored in ~/.config/tto.
EOF

create_deb() {
  local package_root="$work_dir/deb"
  local dependencies
  mkdir -p "$package_root/usr" "$package_root/DEBIAN" "$work_dir/debian"
  cp -R "$bundle/." "$package_root/usr/"
  printf 'Source: tto\n\nPackage: tto\nArchitecture: any\nDescription: Terminal todo manager\n' \
    > "$work_dir/debian/control"
  dependencies="$(cd "$work_dir" && dpkg-shlibdeps -O -e"$package_root/usr/bin/tto")"
  dependencies="${dependencies#shlibs:Depends=}"
  cat > "$package_root/DEBIAN/control" <<EOF
Package: tto
Version: $version
Section: utils
Priority: optional
Architecture: $deb_architecture
Maintainer: Mingyu Choo <mingyuchoo@gmail.com>
Homepage: https://github.com/mingyuchoo/tto
Description: Terminal todo manager built with Brick and SQLite
EOF
  if [ -n "$dependencies" ]; then
    printf 'Depends: %s\n' "$dependencies" >> "$package_root/DEBIAN/control"
  fi
  chmod 755 "$package_root/DEBIAN"
  chmod 644 "$package_root/DEBIAN/control"
  dpkg-deb --build --root-owner-group "$package_root" "$artifacts/$artifact_name.deb"
}

create_rpm() {
  local rpm_root="$work_dir/rpm"
  mkdir -p "$rpm_root/db" "$rpm_root/BUILD" "$rpm_root/BUILDROOT" "$rpm_root/RPMS" \
    "$rpm_root/SOURCES" "$rpm_root/SPECS" "$rpm_root/SRPMS"
  tar -czf "$rpm_root/SOURCES/payload.tar.gz" -C "$bundle" .
  cat > "$rpm_root/SPECS/tto.spec" <<EOF
Name: tto
Version: $version
Release: 1
Summary: Terminal todo manager built with Brick and SQLite
License: BSD-3-Clause
URL: https://github.com/mingyuchoo/tto
Source0: payload.tar.gz

%description
Terminal-based todo manager with configurable keybindings and translations.

%prep

%build

%install
mkdir -p %{buildroot}/usr
tar -xzf %{SOURCE0} -C %{buildroot}/usr

%files
%attr(0755,root,root) /usr/bin/tto
/usr/share/tto
%doc /usr/share/doc/tto
EOF
  rpmbuild --define "_dbpath $rpm_root/db" --define "_topdir $rpm_root" --define 'debug_package %{nil}' \
    --target "$architecture" -bb "$rpm_root/SPECS/tto.spec"
  local packages=("$rpm_root/RPMS/$architecture/"*.rpm)
  [ "${#packages[@]}" -eq 1 ] && [ -f "${packages[0]}" ] || fail 'Expected exactly one RPM package.'
  cp "${packages[0]}" "$artifacts/$artifact_name.rpm"
}

create_macos_package() {
  dylibbundler -b -cd -x "$bundle/bin/tto" -d "$bundle/lib/tto" \
    -p '@executable_path/../lib/tto/'
  local library
  for library in "$bundle/lib/tto/"*.dylib; do
    [ -f "$library" ] || continue
    codesign --force --sign - "$library"
  done
  codesign --force --sign - "$bundle/bin/tto"
  pkgbuild --root "$bundle" --identifier io.github.mingyuchoo.tto \
    --version "$version" --install-location /usr/local --ownership recommended \
    "$artifacts/$artifact_name.pkg"
}

if [ "$platform" = linux ]; then
  if [ "$package_format" != rpm ]; then
    run_step 'Creating Debian installer' create_deb
  fi
  if [ "$package_format" != deb ]; then
    run_step 'Creating RPM installer' create_rpm
  fi
else
  run_step 'Creating macOS installer' create_macos_package
fi

run_step 'Creating archive' tar -czf "$artifacts/$artifact_name.tar.gz" \
  -C "$work_dir" "$artifact_name"

(
  cd "$artifacts"
  if [ "$platform" = linux ]; then
    sha256sum ./* > SHA256SUMS
  else
    shasum -a 256 ./* > SHA256SUMS
  fi
)

mkdir -p "$output_dir"
release_directory="$output_dir/$artifact_name"
lock_candidate="$output_dir/.$artifact_name.lock"
mkdir "$lock_candidate" || fail "Another publication holds the lock: $lock_candidate"
lock_directory="$lock_candidate"
[ ! -e "$release_directory" ] || fail "Release already exists: $release_directory. Choose another --output-dir."
publication_directory="$(mktemp -d "$output_dir/.$artifact_name.XXXXXX")"
cp "$artifacts/"* "$publication_directory/"
mv -- "$publication_directory" "$release_directory"
publication_directory=''
printf '\nRelease artifacts: %s\n' "$release_directory"
