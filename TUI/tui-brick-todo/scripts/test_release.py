import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zipfile


PROJECT_ROOT = Path(__file__).resolve().parent.parent
POWERSHELL = os.environ.get("TTO_PWSH") or shutil.which("pwsh")


class ReleaseFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tto release tests ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "project with spaces"
        self.project.mkdir()
        shutil.copytree(PROJECT_ROOT / "scripts", self.project / "scripts")
        for directory in (
            "apps/tto",
            "packages/domain/src",
            "packages/application/src",
            "packages/terminal/src",
            "test",
            "config",
        ):
            (self.project / directory).mkdir(parents=True)
        for filename in (
            "Setup.hs",
            "apps/tto/Main.hs",
            "packages/domain/src/Example.hs",
            "test/Spec.hs",
        ):
            (self.project / filename).write_text("main = pure ()\n")
        for filename in ("README.md", "CHANGELOG.md", "LICENSE"):
            (self.project / filename).write_text(filename + "\n")
        (self.project / "package.yaml").write_text("name: tto\nversion: 0.1.0.0\n")
        (self.project / "config/keybindings.yaml").write_text("keybindings: {}\n")
        (self.project / "todos.db").write_text("private user data")
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.binary = self.root / "fixture"
        subprocess.run(
            ["gcc", "-x", "c", "-o", str(self.binary), "-"],
            input="int main(void) { return 0; }\n",
            text=True,
            check=True,
        )
        self.install = self.root / "stack install"
        (self.install / "bin").mkdir(parents=True)
        shutil.copy2(self.binary, self.install / "bin/tto-exe")
        self.environment = {
            **os.environ,
            "PATH": str(self.tools) + os.pathsep + os.environ["PATH"],
            "FIXTURE_INSTALL": str(self.install),
            "FIXTURE_TARGET": {
                "aarch64": "aarch64-unknown-linux",
                "x86_64": "x86_64-unknown-linux",
            }[platform.machine()],
        }
        self.write_tool("fourmolu", "exit 0\n")
        self.write_tool("hlint", "exit 0\n")
        self.write_tool(
            "stack",
            'case "$*" in\n'
            '  "path --local-install-root") printf "%s\\n" "$FIXTURE_INSTALL" ;;\n'
            '  "exec -- ghc --print-target-platform") printf "%s\\n" "$FIXTURE_TARGET" ;;\n'
            '  "build --test --no-run-tests --ghc-options=-O2") exit "${FIXTURE_BUILD_EXIT:-0}" ;;\n'
            '  "test --ghc-options=-O2") exit "${FIXTURE_TEST_EXIT:-0}" ;;\n'
            '  *) printf "Unexpected Stack arguments: %s\\n" "$*" >&2; exit 99 ;;\n'
            "esac\n",
        )
        self.output_root = self.root / "output with spaces"
        self.output = self.output_root / ("tto-0.1.0.0-linux-" + platform.machine())

    def write_tool(self, name, body):
        path = self.tools / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
        path.chmod(0o755)

    def release(self, *arguments):
        return subprocess.run(
            [
                "bash",
                str(self.project / "scripts/release.sh"),
                "--output-dir",
                str(self.output_root),
                *arguments,
            ],
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
        )


@unittest.skipUnless(platform.system() == "Linux", "Linux packaging integration tests")
class LinuxReleaseTests(ReleaseFixture):
    def test_deb_archive_metadata_payload_and_checksums(self):
        result = self.release("--package", "deb")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        package = next(self.output.glob("*.deb"))
        metadata = subprocess.check_output(
            ["dpkg-deb", "--field", str(package)], text=True
        )
        self.assertIn("Package: tto\n", metadata)
        self.assertIn("Version: 0.1.0.0\n", metadata)
        self.assertIn("Depends: libc6", metadata)
        expected_architecture = {"aarch64": "arm64", "x86_64": "amd64"}[platform.machine()]
        self.assertIn("Architecture: " + expected_architecture + "\n", metadata)
        extracted = self.root / "extracted"
        subprocess.run(["dpkg-deb", "--extract", str(package), str(extracted)], check=True)
        self.assertTrue(os.access(extracted / "usr/bin/tto", os.X_OK))
        subprocess.run([str(extracted / "usr/bin/tto")], check=True)
        self.assertTrue((extracted / "usr/share/tto/config/keybindings.yaml").is_file())
        with tarfile.open(next(self.output.glob("*.tar.gz"))) as archive:
            self.assertTrue(any(name.endswith("/bin/tto") for name in archive.getnames()))
            self.assertFalse(any(name.endswith("todos.db") for name in archive.getnames()))
        manifest = (self.output / "SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(manifest), 2)
        for line in manifest:
            digest, filename = line.split("  ", 1)
            self.assertEqual(hashlib.sha256((self.output / filename).read_bytes()).hexdigest(), digest)

    def test_rpm_has_native_dependencies_and_payload(self):
        result = self.release("--package", "rpm")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        package = next(self.output.glob("*.rpm"))
        dependencies = subprocess.check_output(
            ["rpm", "--dbpath", str(self.root / "rpmdb"), "-qpR", str(package)], text=True
        )
        self.assertIn("libc.so.6", dependencies)
        files = subprocess.check_output(
            ["rpm", "--dbpath", str(self.root / "rpmdb"), "-qpl", str(package)], text=True
        )
        self.assertIn("/usr/bin/tto\n", files)
        self.assertIn("/usr/share/tto/config/keybindings.yaml\n", files)
        self.assertNotIn("todos.db", files)

    def test_failed_quality_gate_does_not_publish(self):
        for tool in ("fourmolu", "hlint"):
            with self.subTest(tool=tool):
                self.write_tool(tool, "exit 23\n")
                result = self.release("--package", "deb")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("==> Formatting", result.stdout)
                self.assertFalse(self.output.exists())
                self.write_tool(tool, "exit 0\n")
        for variable in ("FIXTURE_BUILD_EXIT", "FIXTURE_TEST_EXIT"):
            with self.subTest(variable=variable):
                self.environment[variable] = "42"
                result = self.release("--package", "deb")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("==> Building", result.stdout)
                self.assertFalse(self.output.exists())
                del self.environment[variable]

    def test_default_builds_both_installers(self):
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("error:", result.stderr)
        self.assertEqual(len(list(self.output.glob("*.deb"))), 1)
        self.assertEqual(len(list(self.output.glob("*.rpm"))), 1)
        self.assertEqual(len((self.output / "SHA256SUMS").read_text().splitlines()), 3)

    def test_existing_release_is_preserved(self):
        self.output.mkdir(parents=True)
        previous = self.output / "SHA256SUMS"
        previous.write_text("previous release\n")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(previous.read_text(), "previous release\n")
        self.assertEqual(list(self.output.iterdir()), [previous])

    def test_packaging_failure_does_not_publish(self):
        self.write_tool("rpmbuild", "exit 23\n")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("==> Creating RPM installer", result.stdout)
        self.assertFalse(self.output.exists())

    def test_publication_copy_failure_leaves_no_release_or_staging(self):
        self.environment["FIXTURE_OUTPUT_ROOT"] = str(self.output_root)
        self.write_tool(
            "cp",
            'case "${!#}" in\n'
            '  "$FIXTURE_OUTPUT_ROOT"/.*) exit 23 ;;\n'
            'esac\nexec /usr/bin/cp "$@"\n',
        )
        result = self.release("--package", "deb")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("==> Creating archive", result.stdout)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.output_root.iterdir()), [])

    def test_unknown_option_fails_without_artifacts(self):
        result = self.release("--unexpected")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown option", result.stderr)
        self.assertFalse(self.output.exists())

    def test_missing_argument_fails_without_artifacts(self):
        result = self.release("--package")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires", result.stderr)
        self.assertFalse(self.output.exists())

    def test_help_needs_no_build_tools(self):
        for tool in self.tools.iterdir():
            tool.unlink()
        self.environment["PATH"] = "/usr/bin:/bin"
        result = self.release("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Usage:", result.stdout)
        self.assertFalse(self.output.exists())


@unittest.skipUnless(POWERSHELL and platform.system() == "Linux", "PowerShell adapter tests on Linux")
class WindowsReleaseTests(ReleaseFixture):
    def setUp(self):
        super().setUp()
        self.environment["OS"] = "Windows_NT"
        self.environment["FIXTURE_TARGET"] = "x86_64-unknown-mingw32"
        self.output = self.output_root / "tto-0.1.0.0-windows-x86_64"
        self.environment["WINDIR"] = str(self.root / "Windows")
        system = self.root / "Windows/System32"
        system.mkdir(parents=True)
        (system / "KERNEL32.dll").write_text("system library")
        shutil.copy2(self.binary, self.install / "bin/tto-exe.exe")
        (self.install / "bin/first.dll").write_text("first runtime")
        (self.install / "bin/second.dll").write_text("second runtime")
        self.write_tool(
            "stack",
            'case "$*" in\n'
            '  "path --local-install-root") printf "%s\\n" "$FIXTURE_INSTALL" ;;\n'
            '  "exec -- ghc --print-target-platform") printf "%s\\n" "$FIXTURE_TARGET" ;;\n'
            '  "exec -- objdump -p "*)\n'
            '    case "$5" in\n'
            '      *tto.exe) printf "DLL Name: first.dll\\nDLL Name: KERNEL32.dll\\n" ;;\n'
            '      *first.dll) printf "DLL Name: second.dll\\n" ;;\n'
            '      *second.dll) printf "DLL Name: first.dll\\n" ;;\n'
            '      *) exit 98 ;;\n'
            '    esac ;;\n'
            '  "exec -- where.exe "*) printf "%s/bin/%s\\n" "$FIXTURE_INSTALL" "$4" ;;\n'
            '  "build --test --no-run-tests --ghc-options=-O2") exit "${FIXTURE_BUILD_EXIT:-0}" ;;\n'
            '  "test --ghc-options=-O2") exit "${FIXTURE_TEST_EXIT:-0}" ;;\n'
            '  *) printf "Unexpected Stack arguments: %s\\n" "$*" >&2; exit 99 ;;\n'
            "esac\n",
        )
        self.write_tool(
            "ISCC.exe",
            'output=""\nname=""\nfor argument in "$@"; do\n'
            '  case "$argument" in\n'
            '    /O*) output="${argument:2}" ;;\n'
            '    /F*) name="${argument:2}" ;;\n'
            '  esac\ndone\n'
            'printf "installer fixture\\n" > "$output/$name.exe"\n',
        )

    def release(self, *arguments):
        return subprocess.run(
            [
                POWERSHELL, "-NoLogo", "-NoProfile", "-File",
                str(self.project / "scripts/release.ps1"),
                "-OutputDir", str(self.output_root), *arguments,
            ],
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
        )

    def test_zip_bundles_transitive_dlls_and_excludes_system_dlls(self):
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with zipfile.ZipFile(next(self.output.glob("*.zip"))) as archive:
            names = archive.namelist()
            self.assertTrue(any(name.endswith("/bin/tto.exe") for name in names))
            self.assertTrue(any(name.endswith("/bin/first.dll") for name in names))
            self.assertTrue(any(name.endswith("/bin/second.dll") for name in names))
            self.assertFalse(any("KERNEL32.dll" in name or "todos.db" in name for name in names))
        self.assertEqual(len(list(self.output.glob("*-setup.exe"))), 1)
        manifest = (self.output / "SHA256SUMS").read_text(encoding="utf-8-sig").splitlines()
        self.assertEqual(len(manifest), 2)
        for line in manifest:
            digest, filename = line.split("  ", 1)
            self.assertEqual(hashlib.sha256((self.output / filename).read_bytes()).hexdigest(), digest)

    def test_failed_build_prevents_windows_artifacts(self):
        self.environment["FIXTURE_BUILD_EXIT"] = "42"
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed with exit code 42", result.stderr)
        self.assertFalse(self.output.exists())

    def test_missing_transitive_dll_prevents_publication(self):
        (self.install / "bin/second.dll").unlink()
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("second.dll", result.stderr)
        self.assertFalse(self.output.exists())

    def test_existing_windows_release_is_preserved(self):
        self.output.mkdir(parents=True)
        previous = self.output / "SHA256SUMS"
        previous.write_text("previous release\n")
        result = self.release()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(previous.read_text(), "previous release\n")
        self.assertEqual(list(self.output.iterdir()), [previous])


if __name__ == "__main__":
    unittest.main()
