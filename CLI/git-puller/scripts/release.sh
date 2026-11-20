#!/usr/bin/env bash
set -euo pipefail

require_commands() {
    local tool
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null; then
            printf 'Required command not found: %s\n' "$tool" >&2
            return 127
        fi
    done
}

stage_bundle() {
    local bundle=$1
    mkdir -p "$bundle/bin"
    install -m 755 "$(cabal list-bin exe:git-puller)" "$bundle/bin/git-puller"
}

stage_installation() {
    local root=$1 bundle=$2 prefix=$3
    mkdir -p "$root$prefix/bin"
    install -m 755 "$bundle/bin/git-puller" "$root$prefix/bin/git-puller"
}

package_deb() {
    local staging_root=$1 version=$2 output=$3 architecture dependencies root
    root="$staging_root/debian/git-puller"
    architecture=$(dpkg --print-architecture)
    mkdir -p "$root/DEBIAN"
    cat >"$root/DEBIAN/control" <<CONTROL
Package: git-puller
Version: $version
Architecture: $architecture
Maintainer: mingyuchoo
Description: Batch Git pull CLI
CONTROL
    printf 'Source: git-puller\n\nPackage: git-puller\nArchitecture: any\n' >"$staging_root/debian/control"
    dependencies=$(cd "$staging_root" && dpkg-shlibdeps -O -edebian/git-puller/usr/bin/git-puller)
    printf 'Depends: git, %s\n' "${dependencies#shlibs:Depends=}" >>"$root/DEBIAN/control"
    dpkg-deb --root-owner-group --build "$root" "$output/git-puller_${version}_${architecture}.deb"
}

package_rpm() {
    local root=$1 version=$2 output=$3 topdir="$3/rpmbuild"
    mkdir -p "$topdir"
    GIT_PULLER_PACKAGE_ROOT="$root" rpmbuild -bb --nodeps \
        --define "_topdir $topdir" --define "release_version $version" \
        scripts/packaging/git-puller.spec
    cp "$topdir"/RPMS/*/git-puller-*.rpm "$output/"
}

project_version() {
    local project=$1 version
    version=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)[[:space:]]*$/\1/p' "$project")
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf 'Expected exactly one version: MAJOR.MINOR.PATCH field in %s\n' "$project" >&2
        return 2
    fi
    printf '%s\n' "$version"
}

main() (
    local mode=${1:-installers} output=${2:-dist}
    if [[ $mode != installers && $mode != --bundle-only ]] || (($# > 2)); then
        printf 'Usage: %s [installers|--bundle-only] [OUTPUT_DIRECTORY]\n' "$0" >&2
        return 2
    fi

    local workspace version platform architecture name bundle package_root
    workspace=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
    version=$(project_version "$workspace/apps/git-puller/git-puller.cabal")
    case $(uname -s) in
    Linux) platform=linux ;;
    Darwin) platform=macos ;;
    *)
        printf 'Release building requires Linux or macOS.\n' >&2
        return 2
        ;;
    esac
    architecture=$(uname -m)
    require_commands tar install cabal ghc
    if [[ $mode == installers ]]; then
        if [[ $platform == linux ]]; then
            require_commands dpkg dpkg-deb dpkg-shlibdeps rpmbuild
        else
            require_commands pkgbuild
        fi
    fi

    cd -- "$workspace"
    mkdir -p -- "$output"
    output=$(cd -- "$output" && pwd -P)
    local compiler
    compiler=$(ghc --numeric-version)
    if [[ $compiler != 9.10.3 ]]; then
        printf 'Expected GHC 9.10.3, got %s\n' "$compiler" >&2
        return 2
    fi
    cabal build -O2 exe:git-puller

    printf '\n==> Bundle\n'
    staging=$(mktemp -d "${TMPDIR:-/tmp}/git-puller-release.XXXXXXXX")
    trap 'rm -rf -- "$staging"' EXIT
    name="git-puller-$version-$platform-$architecture"
    bundle="$staging/$name"
    stage_bundle "$bundle"
    "$bundle/bin/git-puller" --dry-run "$staging"
    tar -czf "$staging/$name.tar.gz" -C "$staging" "$name"

    if [[ $mode == installers ]]; then
        printf '\n==> Package\n'
        if [[ $platform == linux ]]; then
            package_root="$staging/debian/git-puller"
            stage_installation "$package_root" "$bundle" /usr
            "$package_root/usr/bin/git-puller" --dry-run "$staging"
            package_rpm "$package_root" "$version" "$staging"
            package_deb "$staging" "$version" "$staging"
            mv -- "$staging"/*.deb "$staging"/*.rpm "$output/"
        else
            stage_installation "$staging/root" "$bundle" /usr/local
            "$staging/root/usr/local/bin/git-puller" --dry-run "$staging"
            pkgbuild --root "$staging/root" --identifier org.mingyuchoo.git-puller \
                --version "$version" --install-location / "$staging/$name.pkg"
            mv -- "$staging/$name.pkg" "$output/"
        fi
    fi
    mv -- "$staging/$name.tar.gz" "$output/"
    printf '\nArtifacts written to %s\n' "$output"
)

main "$@"
