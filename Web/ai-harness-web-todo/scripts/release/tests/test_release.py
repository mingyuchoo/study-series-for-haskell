import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from bundle import copy_library, create_archive, linux_launcher, write_checksums
from installers import install_tree
from release import validate_repository


class WindowsValidationTests(unittest.TestCase):
    def test_context_generators_match_canonical_documents_with_windows_newlines(self):
        root = Path(__file__).resolve().parents[3]
        generators = {
            "generate-db-schema.sh": ["db-schema.md"],
            "generate-api-index.sh": ["api-index.md"],
            "generate-dependency-map.sh": ["dependency-graph.md", "service-map.md"],
            "generate-route-map.sh": ["route-map.md"],
        }
        write_text = Path.write_text

        def windows_write_text(path, data, *arguments, **keywords):
            keywords.setdefault("newline", "\r\n")
            return write_text(path, data, *arguments, **keywords)

        with tempfile.TemporaryDirectory() as temporary:
            for name, documents in generators.items():
                with self.subTest(generator=name):
                    script = root / "scripts/context" / name
                    body = (
                        script.read_text(encoding="utf-8")
                        .split("<<'PY'\n", 1)[1]
                        .split("\nPY\n", 1)[0]
                    )
                    outputs = [Path(temporary) / document for document in documents]
                    with (
                        patch.object(Path, "write_text", windows_write_text),
                        patch.object(
                            sys, "argv", [name, str(root), *map(str, outputs)]
                        ),
                    ):
                        exec(
                            compile(body, str(script), "exec"), {"__name__": "__main__"}
                        )
                    for document, output in zip(documents, outputs, strict=True):
                        self.assertEqual(
                            output.read_bytes(),
                            (root / "docs/generated" / document).read_bytes(),
                        )

    def test_git_bash_python_shim_uses_lf_even_with_windows_default_newlines(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src").mkdir()
            (root / "src/Main.hs").write_text("module Main where\nmain = pure ()\n")
            workspace = root / "workspace"
            workspace.mkdir()
            write_text = Path.write_text

            def windows_write_text(path, data, *arguments, **keywords):
                keywords.setdefault("newline", "\r\n")
                return write_text(path, data, *arguments, **keywords)

            with (
                patch.object(Path, "write_text", windows_write_text),
                patch("release.run_command"),
            ):
                validate_repository(root, workspace, "check", "windows")
            shim = (workspace / "tools/python3").read_bytes()
            self.assertTrue(shim.startswith(b"#!/bin/sh\n"))
            self.assertNotIn(b"\r", shim)


class BundleTests(unittest.TestCase):
    def test_conflicting_libraries_cannot_silently_replace_existing_dependencies(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.dll"
            source.write_bytes(b"new")
            destination = root / "installed.dll"
            destination.write_bytes(b"existing")
            with self.assertRaisesRegex(ValueError, "Conflicting"):
                copy_library(source, destination)
            self.assertEqual(destination.read_bytes(), b"existing")

    def test_windows_zip_keeps_all_binaries_under_one_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "todo-1.0-windows-x64"
            (bundle / "bin").mkdir(parents=True)
            (bundle / "bin/todo.exe").write_bytes(b"executable")
            (bundle / "bin/gmp.dll").write_bytes(b"library")
            archive = create_archive(bundle, root, "windows")
            with zipfile.ZipFile(archive) as handle:
                self.assertEqual(
                    set(handle.namelist()),
                    {
                        "todo-1.0-windows-x64/bin/todo.exe",
                        "todo-1.0-windows-x64/bin/gmp.dll",
                    },
                )

    def test_unix_install_tree_ships_no_user_database(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "bundle"
            bundle.mkdir()
            (bundle / "README.md").write_text("instructions")
            payload = root / "payload"
            install_tree(bundle, payload, "usr")
            self.assertTrue((payload / "usr/lib/haskell-todo/README.md").is_file())
            self.assertEqual(
                {path.name for path in (payload / "usr/bin").iterdir()},
                {"todo", "todo-api", "todo-web"},
            )
            self.assertEqual(list(payload.rglob("*.db")), [])

    def test_launcher_preserves_working_directory_and_arguments_with_spaces(self):
        if os.name == "nt":
            self.skipTest("POSIX launcher")
        with tempfile.TemporaryDirectory(prefix="release test ") as temporary:
            root = Path(temporary)
            bundle = root / "bundle with spaces"
            (bundle / "bin").mkdir(parents=True)
            (bundle / "libexec").mkdir()
            (bundle / "lib").mkdir()
            executable = bundle / "libexec/cli"
            executable.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$PWD" "$1" "$LD_LIBRARY_PATH"\n',
                encoding="utf-8",
            )
            executable.chmod(0o755)
            launcher = bundle / "bin/todo"
            launcher.write_text(linux_launcher("cli"), encoding="utf-8")
            launcher.chmod(0o755)
            output = subprocess.check_output(
                [str(launcher), "a b"], cwd=root, text=True
            ).splitlines()
            self.assertEqual(output[:2], [str(root), "a b"])
            self.assertEqual(output[2].split(os.pathsep)[0], str(bundle / "lib"))

    def test_archive_and_checksums_include_only_release_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / "todo-1.0-linux-x64"
            (bundle / "bin").mkdir(parents=True)
            (bundle / "bin/todo").write_bytes(b"binary")
            archive = create_archive(bundle, root, "linux")
            with tarfile.open(archive) as handle:
                self.assertIn("todo-1.0-linux-x64/bin/todo", handle.getnames())
            write_checksums(root, [archive])
            expected = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual(
                (root / "SHA256SUMS").read_text(), f"{expected}  {archive.name}\n"
            )


@unittest.skipUnless(platform.system() == "Linux", "Linux native pipeline")
class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="release pipeline ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "project with spaces"
        source = Path(__file__).resolve().parents[2]
        shutil.copytree(
            source / "release",
            self.project / "scripts/release",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copy2(source / "release.sh", self.project / "scripts/release.sh")
        for name in ("core", "store", "cli", "api", "web"):
            package = self.project / "src" / name
            package.mkdir(parents=True)
            (package / f"{name}.cabal").write_text(f"name: {name}\nversion: 0.1.0.0\n")
            (package / "Main.hs").write_text("module Main where\nmain = pure ()\n")
        for name in (
            "run.sh",
            "quality/lint.sh",
            "quality/architecture-check.sh",
            "context/validate-context.sh",
        ):
            script = self.project / "scripts" / name
            script.parent.mkdir(parents=True, exist_ok=True)
            script.write_text(
                '#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$RELEASE_TEST_LOG"\n'
            )
        tools = self.root / "tools"
        tools.mkdir()
        triple = (
            "aarch64-unknown-linux"
            if platform.machine() == "aarch64"
            else "x86_64-unknown-linux"
        )
        programs = {
            "ghc": f'case "$1" in --numeric-version) echo 9.10.3;; --print-target-platform) echo {triple};; esac',
            "cabal": 'case "$1" in --numeric-version) echo 3.16.1.0;; test) exit 23;; esac',
            "fourmolu": "exit 0",
            "hlint": "exit 0",
            "ldd": "exit 0",
            "getconf": "echo glibc 2.39",
            "dpkg-deb": "exit 0",
            "rpmbuild": "exit 0",
        }
        for name, body in programs.items():
            program = tools / name
            program.write_text(
                f'#!/bin/sh\nprintf "%s\\n" "{name} $*" >> "$RELEASE_TEST_LOG"\n{body}\n'
            )
            program.chmod(0o755)
        self.environment = {
            **os.environ,
            "PATH": str(tools) + os.pathsep + os.environ["PATH"],
            "RELEASE_TEST_LOG": str(self.root / "commands.log"),
        }
        self.output = self.root / "output with spaces"

    def execute(self, *arguments):
        return subprocess.run(
            [
                "bash",
                str(self.project / "scripts/release.sh"),
                "--output",
                str(self.output),
                *arguments,
            ],
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_failed_haskell_tests_publish_no_artifacts_and_propagate_failure(self):
        result = self.execute()
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        self.assertFalse(list(self.root.glob(".todo-release-*")))

    def test_existing_output_is_preserved_before_running_build_tools(self):
        self.output.mkdir()
        marker = self.output / "previous.deb"
        marker.write_text("keep")
        result = self.execute()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker.read_text(), "keep")
        self.assertFalse((self.root / "commands.log").exists())

    def test_check_only_does_not_format_build_or_create_output(self):
        result = self.execute("--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        commands = (self.root / "commands.log").read_text()
        self.assertNotIn("cabal build", commands)
        self.assertNotIn("scripts/run.sh", commands)

    def test_formatter_failure_stops_before_building(self):
        (Path(self.environment["PATH"].split(os.pathsep)[0]) / "fourmolu").write_text(
            "#!/bin/sh\nexit 19\n"
        )
        result = self.execute()
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        self.assertNotIn("cabal build", (self.root / "commands.log").read_text())

    def test_lint_failure_stops_before_building(self):
        (self.project / "scripts/quality/lint.sh").write_text("#!/bin/sh\nexit 17\n")
        result = self.execute()
        self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
        self.assertFalse(self.output.exists())
        self.assertNotIn("cabal build", (self.root / "commands.log").read_text())

    def test_missing_required_tool_stops_before_formatting(self):
        tools = Path(self.environment["PATH"].split(os.pathsep)[0])
        (tools / "hlint").unlink()
        for name, executable in (
            ("bash", shutil.which("bash")),
            ("dirname", shutil.which("dirname")),
            ("python3", sys.executable),
        ):
            (tools / name).symlink_to(executable)
        self.environment["PATH"] = str(tools)
        result = self.execute()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Missing release tools: hlint", result.stderr)
        self.assertFalse(self.output.exists())
        self.assertFalse((self.root / "commands.log").exists())


if __name__ == "__main__":
    unittest.main()
