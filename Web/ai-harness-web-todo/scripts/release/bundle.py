import hashlib
import os
import shutil
import socket
import subprocess
import tarfile
import time
import zipfile
from pathlib import Path
from urllib.error import URLError
from urllib.request import ProxyHandler, build_opener

from commands import run_command, runtime_environment
from metadata import linux_libraries, windows_libraries

EXECUTABLES = {"cli": "todo", "api": "todo-api", "web": "todo-web"}


def linux_launcher(executable: str) -> str:
    return (
        "#!/bin/sh\nset -eu\n"
        'bundle_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"\n'
        'export LD_LIBRARY_PATH="$bundle_root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
        f'exec "$bundle_root/libexec/{executable}" "$@"\n'
    )


def copy_library(source: Path, destination: Path) -> None:
    if destination.exists():
        if (
            hashlib.sha256(destination.read_bytes()).digest()
            != hashlib.sha256(source.read_bytes()).digest()
        ):
            raise ValueError(f"Conflicting runtime libraries: {destination.name}")
    else:
        shutil.copy2(source, destination)


def bundle_linux(bundle: Path) -> None:
    library_directory = bundle / "lib"
    library_directory.mkdir()
    for executable, name in EXECUTABLES.items():
        binary = bundle / "libexec" / executable
        listing = run_command(["ldd", binary], cwd=bundle, capture=True)
        for library, source in linux_libraries(listing).items():
            if library.startswith("libHS"):
                raise ValueError(
                    "Haskell shared libraries must be disabled for releases"
                )
            copy_library(Path(source), library_directory / library)
        launcher = bundle / "bin" / name
        launcher.write_text(linux_launcher(executable), encoding="utf-8")
        launcher.chmod(0o755)


def bundle_macos(bundle: Path) -> None:
    libraries = bundle / "lib"
    command = [
        "dylibbundler",
        "-b",
        "-cd",
        "-d",
        str(libraries),
        "-p",
        "@executable_path/../lib/",
    ]
    for name in EXECUTABLES.values():
        command.extend(["-x", str(bundle / "bin" / name)])
    run_command(command, cwd=bundle)
    for binary in sorted(libraries.glob("*.dylib")) + sorted(
        (bundle / "bin").iterdir()
    ):
        run_command(["codesign", "--force", "--sign", "-", binary], cwd=bundle)


def bundle_windows(
    bundle: Path, originals: list[Path], compiler_directory: Path
) -> None:
    candidates = {}
    directories = [binary.parent for binary in originals]
    directories.extend(Path(entry) for entry in os.get_exec_path() if entry)
    for directory in directories:
        if directory.is_dir():
            for library in directory.glob("*.dll"):
                candidates.setdefault(library.name.lower(), library)
    for library in compiler_directory.parent.rglob("*.dll"):
        candidates.setdefault(library.name.lower(), library)
    pending = list((bundle / "bin").glob("*.exe"))
    inspected = set()
    system_directory = Path(os.environ["SystemRoot"]) / "System32"
    while pending:
        binary = pending.pop()
        if binary.name.lower() in inspected:
            continue
        inspected.add(binary.name.lower())
        listing = run_command(["objdump", "-p", binary], cwd=bundle, capture=True)
        for name in windows_libraries(listing):
            key = name.lower()
            if (
                key.startswith(("api-ms-", "ext-ms-"))
                or (system_directory / name).exists()
            ):
                continue
            source = candidates.get(key)
            if source is None:
                raise ValueError(f"Unresolved Windows runtime dependency: {name}")
            destination = bundle / "bin" / name
            copy_library(source, destination)
            pending.append(destination)
    (bundle / "bin/todo-shell.cmd").write_text(
        '@echo off\nset "PATH=%~dp0;%PATH%"\n'
        'if not exist "%LOCALAPPDATA%\\Todo" mkdir "%LOCALAPPDATA%\\Todo"\n'
        'cd /d "%LOCALAPPDATA%\\Todo"\n',
        encoding="utf-8",
    )


def prepare_bundle(root: Path, bundle: Path, system: str, flags: list[str]) -> None:
    (bundle / "bin").mkdir(parents=True)
    (bundle / "libexec").mkdir()
    originals = []
    for executable, name in EXECUTABLES.items():
        source = Path(
            run_command(
                ["cabal", "list-bin", f"{executable}:exe:{executable}", *flags],
                cwd=root,
                capture=True,
            )
        )
        if not source.is_file():
            raise ValueError(f"Cabal did not produce {executable}: {source}")
        originals.append(source)
        destination = (
            bundle / "libexec" / executable
            if system == "linux"
            else bundle / "bin" / (name + (".exe" if system == "windows" else ""))
        )
        shutil.copy2(source, destination)
        destination.chmod(0o755)
    if system == "linux":
        bundle_linux(bundle)
    elif system == "macos":
        bundle_macos(bundle)
    else:
        compiler_directory = Path(
            run_command(["ghc", "--print-libdir"], cwd=root, capture=True)
        )
        bundle_windows(bundle, originals, compiler_directory)
    shutil.copy2(root / "docs/RELEASE.md", bundle / "README.md")
    for license_file in root.glob("LICENSE*"):
        if license_file.is_file():
            shutil.copy2(license_file, bundle / license_file.name)


def smoke_test(bundle: Path, system: str, workspace: Path) -> None:
    extension = ".exe" if system == "windows" else ""
    environment = runtime_environment()
    environment["TODO_DB"] = str(workspace / "smoke.db")
    run_command(
        [bundle / "bin" / f"todo{extension}", "--help"], cwd=workspace, env=environment
    )
    run_command(
        [bundle / "bin" / f"todo{extension}", "add", "release-smoke"],
        cwd=workspace,
        env=environment,
    )
    opener = build_opener(ProxyHandler({}))
    for name, variable, route in (
        ("todo-api", "TODO_API_PORT", "/todos"),
        ("todo-web", "TODO_WEB_PORT", "/"),
    ):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            environment[variable] = str(listener.getsockname()[1])
        log = workspace / f"{name}.log"
        with log.open("wb") as handle:
            process = subprocess.Popen(
                [str(bundle / "bin" / f"{name}{extension}")],
                cwd=workspace,
                env=environment,
                stdout=handle,
                stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 15
                while True:
                    if process.poll() is not None:
                        raise ValueError(
                            f"{name} exited during smoke test: {log.read_text(errors='replace')}"
                        )
                    try:
                        with opener.open(
                            f"http://127.0.0.1:{environment[variable]}{route}",
                            timeout=1,
                        ) as response:
                            if (
                                response.status != 200
                                or b"release-smoke" not in response.read()
                            ):
                                raise ValueError(
                                    f"{name} did not read the smoke test database"
                                )
                            break
                    except URLError:
                        if time.monotonic() >= deadline:
                            raise ValueError(
                                f"{name} startup timed out: {log.read_text(errors='replace')}"
                            )
                        time.sleep(0.1)
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def create_archive(bundle: Path, output: Path, system: str) -> Path:
    archive = output / (bundle.name + (".zip" if system == "windows" else ".tar.gz"))
    if system == "windows":
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as handle:
            for source in sorted(bundle.rglob("*")):
                if source.is_file():
                    handle.write(source, source.relative_to(bundle.parent))
    else:
        with tarfile.open(archive, "w:gz") as handle:
            handle.add(bundle, arcname=bundle.name)
    return archive


def write_checksums(output: Path, artifacts: list[Path]) -> None:
    lines = []
    for artifact in sorted(artifacts):
        with artifact.open("rb") as handle:
            digest = hashlib.file_digest(handle, "sha256").hexdigest()
        lines.append(f"{digest}  {artifact.name}\n")
    (output / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")
