import argparse
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from bundle import create_archive, prepare_bundle, smoke_test, write_checksums
from commands import run_command
from installers import create_installers
from metadata import compiler_target, package_version


def require_tools(names: list[str]) -> None:
    missing = [name for name in names if shutil.which(name) is None]
    if missing:
        raise ValueError(
            "Missing release tools: " + ", ".join(missing) + ". See docs/RELEASE.md"
        )


def preflight(root: Path) -> tuple[str, str]:
    require_tools(["ghc", "cabal", "fourmolu", "hlint", "bash"])
    for executable, minimum in (("ghc", (9, 10)), ("cabal", (3, 16))):
        version = run_command([executable, "--numeric-version"], cwd=root, capture=True)
        if tuple(int(part) for part in version.split(".")) < minimum:
            raise ValueError(
                f"{executable} version must be at least {'.'.join(map(str, minimum))}"
            )
    triple = run_command(["ghc", "--print-target-platform"], cwd=root, capture=True)
    system, architecture = compiler_target(
        triple, platform.system(), platform.machine()
    )
    tools = {
        "linux": ["ldd", "getconf", "dpkg-deb", "rpmbuild"],
        "macos": ["dylibbundler", "codesign", "pkgbuild"],
        "windows": ["objdump", "ISCC.exe"],
    }
    require_tools(tools[system])
    if system == "windows":
        bash_system = run_command(["bash", "-c", "uname -s"], cwd=root, capture=True)
        if not bash_system.startswith(("MINGW", "MSYS")):
            raise ValueError("Windows releases require Git Bash, not WSL bash")
    return system, architecture


def validate_repository(
    root: Path, workspace: Path, formatting: str, system: str
) -> None:
    environment = dict(os.environ)
    if system == "windows":
        shims = workspace / "tools"
        shims.mkdir()
        interpreter = shlex.quote(sys.executable.replace("\\", "/"))
        (shims / "python3").write_text(
            f'#!/bin/sh\nexec {interpreter} "$@"\n', encoding="utf-8", newline="\n"
        )
        environment["PATH"] = str(shims) + os.pathsep + environment["PATH"]
    sources = sorted(
        path
        for path in (root / "src").rglob("*.hs")
        if "dist-newstyle" not in path.parts
    )
    if not sources:
        raise ValueError("No Haskell source files found")
    run_command(["fourmolu", "--mode", formatting, *sources], cwd=root, env=environment)
    for arguments in (
        ["bash", "scripts/quality/lint.sh"],
        ["bash", "scripts/quality/architecture-check.sh"],
        ["bash", "scripts/context/validate-context.sh"],
    ):
        run_command(arguments, cwd=root, env=environment)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Format, lint, build, test, bundle and create native installers. See docs/RELEASE.md."
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="New output directory; relative to the caller's working directory",
    )
    parser.add_argument(
        "--format",
        choices=("inplace", "check"),
        default="inplace",
        help="Apply formatting (default) or check without modifying sources",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check metadata and required tools without building or writing output",
    )
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if arguments.output is not None and arguments.output.exists():
        raise ValueError(
            f"Output directory already exists; choose a new --output: {arguments.output}"
        )
    version = package_version(
        [
            path.read_text(encoding="utf-8")
            for path in sorted((root / "src").glob("*/*.cabal"))
        ]
    )
    system, architecture = preflight(root)
    output = (
        arguments.output or root / "dist/release" / version / f"{system}-{architecture}"
    ).absolute()
    if output.exists():
        raise ValueError(
            f"Output directory already exists; choose a new --output: {output}"
        )
    print(f"Release: {version} {system}/{architecture}\nOutput: {output}", flush=True)
    if arguments.check:
        return 0
    flags = [
        "--disable-shared",
        "--disable-executable-dynamic",
        "--ghc-options=-Werror",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".todo-release-", dir=output.parent
    ) as temporary:
        workspace = Path(temporary)
        validate_repository(root, workspace, arguments.format, system)
        run_command(["cabal", "build", "all", *flags], cwd=root)
        run_command(
            ["cabal", "test", "all", *flags, "--test-show-details=direct"], cwd=root
        )
        bundle = workspace / f"todo-{version}-{system}-{architecture}"
        prepare_bundle(root, bundle, system, flags)
        smoke_test(bundle, system, workspace)
        artifacts = workspace / "artifacts"
        artifacts.mkdir()
        archive = create_archive(bundle, artifacts, system)
        installers = create_installers(
            bundle, artifacts, workspace, version, system, architecture
        )
        write_checksums(artifacts, [archive, *installers])
        artifacts.rename(output)
    print(f"Release artifacts created: {output}", flush=True)
    return 0


if __name__ == "__main__":
    try:
        if sys.version_info < (3, 11):
            raise ValueError("Python 3.11 or newer is required")
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(
            f"Release stopped: command failed with exit code {error.returncode}",
            file=sys.stderr,
        )
        sys.exit(error.returncode if 0 < error.returncode < 256 else 1)
    except (ValueError, OSError) as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)
