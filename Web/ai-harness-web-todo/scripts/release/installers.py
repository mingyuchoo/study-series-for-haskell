import shutil
import tempfile
from pathlib import Path

from bundle import EXECUTABLES
from commands import run_command


def install_tree(bundle: Path, payload: Path, prefix: str) -> None:
    destination = payload / prefix / "lib/haskell-todo"
    shutil.copytree(bundle, destination)
    binaries = payload / prefix / "bin"
    binaries.mkdir(parents=True)
    for name in EXECUTABLES.values():
        launcher = binaries / name
        launcher.write_text(
            f'#!/bin/sh\nexec /{prefix}/lib/haskell-todo/bin/{name} "$@"\n',
            encoding="utf-8",
        )
        launcher.chmod(0o755)


def linux_installers(
    bundle: Path, output: Path, workspace: Path, version: str, architecture: str
) -> list[Path]:
    glibc = run_command(["getconf", "GNU_LIBC_VERSION"], cwd=workspace, capture=True)
    if (
        not glibc.startswith("glibc ")
        or not glibc.removeprefix("glibc ").replace(".", "").isdigit()
    ):
        raise ValueError("Linux releases require glibc and its version information")
    glibc_version = glibc.split()[1]
    payload = workspace / "deb-root"
    install_tree(bundle, payload, "usr")
    control = payload / "DEBIAN/control"
    control.parent.mkdir()
    deb_architecture = {"x64": "amd64", "arm64": "arm64"}[architecture]
    control.write_text(
        f"Package: haskell-todo\nVersion: {version}\nArchitecture: {deb_architecture}\n"
        "Maintainer: Todo Maintainers <maintainers@example.invalid>\n"
        "Section: utils\nPriority: optional\n"
        f"Depends: libc6 (>= {glibc_version})\n"
        "Description: Local-first Haskell todo application\n"
        " CLI, loopback HTTP API and browser interface with SQLite storage.\n",
        encoding="utf-8",
    )
    deb = output / f"{bundle.name}.deb"
    run_command(
        ["dpkg-deb", "--root-owner-group", "--build", payload, deb], cwd=workspace
    )
    rpm_architecture = {"x64": "x86_64", "arm64": "aarch64"}[architecture]
    with tempfile.TemporaryDirectory(prefix="todo-rpm-") as temporary:
        top = Path(temporary)
        install_tree(bundle, top / "SOURCES/payload", "usr")
        spec = top / "todo.spec"
        spec.write_text(
            f"Name: haskell-todo\nVersion: {version}\nRelease: 1\n"
            "Summary: Local-first Haskell todo application\nLicense: MIT\n"
            f"BuildArch: {rpm_architecture}\nRequires: glibc >= {glibc_version}\nRequires: /bin/sh\n"
            "AutoReqProv: no\n\n%description\n"
            "CLI, loopback HTTP API and browser interface with SQLite storage.\n\n"
            "%prep\n\n%build\n\n%install\n"
            'mkdir -p "%{buildroot}"\ncp -a "%{_sourcedir}/payload/." "%{buildroot}/"\n\n'
            "%files\n/usr/bin/todo\n/usr/bin/todo-api\n/usr/bin/todo-web\n/usr/lib/haskell-todo\n",
            encoding="utf-8",
        )
        run_command(
            [
                "rpmbuild",
                "--define",
                f"_topdir {top}",
                "--define",
                "_build_id_links none",
                "--define",
                "__os_install_post %{nil}",
                "-bb",
                spec,
            ],
            cwd=top,
        )
        packages = list((top / "RPMS").rglob("*.rpm"))
        if len(packages) != 1:
            raise ValueError("rpmbuild must produce exactly one binary RPM")
        rpm = output / f"{bundle.name}.rpm"
        shutil.copy2(packages[0], rpm)
    return [deb, rpm]


def macos_installer(
    bundle: Path, output: Path, workspace: Path, version: str
) -> list[Path]:
    payload = workspace / "pkg-root"
    install_tree(bundle, payload, "usr/local")
    installer = output / f"{bundle.name}.pkg"
    run_command(
        [
            "pkgbuild",
            "--root",
            payload,
            "--identifier",
            "io.github.mingyuchoo.haskell-todo",
            "--version",
            version,
            "--install-location",
            "/",
            "--ownership",
            "recommended",
            installer,
        ],
        cwd=workspace,
    )
    return [installer]


def windows_installer(
    bundle: Path, output: Path, workspace: Path, version: str, architecture: str
) -> list[Path]:
    target = {"x64": "x64compatible", "arm64": "arm64"}[architecture]
    script = workspace / "todo.iss"
    script.write_text(
        "[Setup]\nAppId={{0968B68A-A084-479A-9824-26BD6BAE172F}\n"
        f"AppName=Haskell Todo\nAppVersion={version}\nAppPublisher=Todo Maintainers\n"
        "DefaultDirName={localappdata}\\Programs\\HaskellTodo\n"
        "DefaultGroupName=Haskell Todo\nPrivilegesRequired=lowest\n"
        f"ArchitecturesAllowed={target}\nArchitecturesInstallIn64BitMode={target}\n"
        "MinVersion=10.0.22000\nCompression=lzma2\nSolidCompression=yes\n"
        f"OutputDir={output}\nOutputBaseFilename={bundle.name}-setup\n"
        "UninstallDisplayIcon={app}\\bin\\todo.exe\n\n"
        "[Files]\n"
        f'Source: "{bundle}\\*"; DestDir: "{{app}}"; Flags: ignoreversion recursesubdirs createallsubdirs\n\n'
        '[Dirs]\nName: "{localappdata}\\Todo"; Flags: uninsneveruninstall\n\n'
        '[Icons]\nName: "{group}\\Todo Command Prompt"; Filename: "{cmd}"; '
        'Parameters: "/K ""{app}\\bin\\todo-shell.cmd"""; WorkingDir: "{localappdata}\\Todo"\n'
        'Name: "{group}\\Todo Web"; Filename: "{app}\\bin\\todo-web.exe"; WorkingDir: "{localappdata}\\Todo"\n'
        'Name: "{group}\\Todo API"; Filename: "{app}\\bin\\todo-api.exe"; WorkingDir: "{localappdata}\\Todo"\n',
        encoding="utf-8-sig",
    )
    run_command(["ISCC.exe", "/Qp", script], cwd=workspace)
    return [output / f"{bundle.name}-setup.exe"]


def create_installers(
    bundle: Path,
    output: Path,
    workspace: Path,
    version: str,
    system: str,
    architecture: str,
) -> list[Path]:
    if system == "linux":
        return linux_installers(bundle, output, workspace, version, architecture)
    if system == "macos":
        return macos_installer(bundle, output, workspace, version)
    return windows_installer(bundle, output, workspace, version, architecture)
