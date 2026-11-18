import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipIf(os.name == "nt", "Bash runner checks require Unix")
class BashRunner(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="hfm scripts 한글 ")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.root = self.directory / "project [workspace]"
        (self.root / "scripts").mkdir(parents=True)
        shutil.copy2(Path(__file__).with_name("run.sh"), self.root / "scripts/run.sh")
        self.sources = [
            "apps/hfm/app/Main.hs",
            "packages/hfm-domain/src/Some file 한글.hs",
            "packages/hfm-domain/test/Spec.hs",
        ]
        for name in self.sources + [
            "packages/hfm-domain/.stack-work/Generated.hs",
            "apps/hfm/dist/Generated.hs",
            "packages/hfm-domain/dist-newstyle/Generated.hs",
        ]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("module Main where\n", encoding="utf-8")
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        tool = self.bin / "tool"
        tool.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "with open(os.environ['HFM_TEST_LOG'], 'a', encoding='utf-8') as log:\n"
            "    log.write(json.dumps({'name': name, 'args': sys.argv[1:], 'cwd': os.getcwd()}) + '\\n')\n"
            "failure = os.environ.get('HFM_TEST_FAIL', '')\n"
            "stage = name + ':' + (sys.argv[1] if len(sys.argv) > 1 else '')\n"
            "sys.exit(7 if failure in (name, stage) else 0)\n",
            encoding="utf-8",
        )
        tool.chmod(0o755)
        for name in ("stack", "python3", "stylish-haskell", "hlint"):
            (self.bin / name).symlink_to(tool)
        self.log = self.directory / "calls.jsonl"
        self.caller = self.directory / "caller"
        self.caller.mkdir()
        self.scratch = self.directory / "temporary files"
        self.scratch.mkdir()
        (self.caller / "left 한글 [files]").mkdir()
        (self.caller / "right files").mkdir()

    def invoke(self, *arguments, failure=""):
        self.log.write_text("")
        environment = {
            **os.environ,
            "PATH": str(self.bin) + os.pathsep + "/usr/bin:/bin",
            "HFM_TEST_LOG": str(self.log),
            "HFM_TEST_FAIL": failure,
            "TMPDIR": str(self.scratch),
        }
        result = subprocess.run(
            [shutil.which("bash"), str(self.root / "scripts/run.sh"), *arguments],
            cwd=self.caller,
            env=environment,
            text=True,
            capture_output=True,
        )
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return result, calls

    def test_all_and_default_run_the_complete_pipeline(self):
        for arguments in [(), ("all",)]:
            with self.subTest(arguments=arguments):
                result, calls = self.invoke(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    [(call["name"], call["args"][0]) for call in calls],
                    [
                        ("stylish-haskell", "--config"),
                        ("hlint", self.sources[0]),
                        ("stack", "build"),
                        ("python3", "scripts/check-architecture.py"),
                        ("python3", "scripts/test-architecture.py"),
                        ("stack", "test"),
                        ("stack", "run"),
                    ],
                )
                self.assertTrue(all(call["cwd"] == str(self.root) for call in calls))

    def test_format_and_lint_only_receive_workspace_sources(self):
        for command, tool in [("format", "stylish-haskell"), ("lint", "hlint")]:
            with self.subTest(command=command):
                result, calls = self.invoke(command)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(calls), 1)
                self.assertEqual(calls[0]["name"], tool)
                sources = [argument for argument in calls[0]["args"] if argument.endswith(".hs")]
                self.assertCountEqual(sources, self.sources)
                if command == "format":
                    self.assertEqual(calls[0]["args"][:3], ["--config", ".stylish-haskell.yaml", "-i"])

    def test_all_stops_at_each_failed_stage_and_preserves_exit_code(self):
        for stage, count in [
            ("stylish-haskell", 1),
            ("hlint", 2),
            ("stack:build", 3),
            ("python3:scripts/check-architecture.py", 4),
            ("python3:scripts/test-architecture.py", 5),
            ("stack:test", 6),
            ("stack:run", 7),
        ]:
            with self.subTest(stage=stage):
                result, calls = self.invoke("all", failure=stage)
                self.assertEqual(result.returncode, 7, result.stderr)
                self.assertEqual(len(calls), count)

    def test_starting_directories_resolve_from_the_callers_location(self):
        for command in ("run", "all"):
            with self.subTest(command=command):
                result, calls = self.invoke(command, "left 한글 [files]", "right files")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls[-1]["args"], [
                    "run", "hfm", "--",
                    str(self.caller / "left 한글 [files]"), str(self.caller / "right files"),
                ])

    def test_invalid_arguments_never_invoke_tools(self):
        for arguments in [
            ("unknown",), ("build", "."), ("format", "."), ("lint", "."),
            ("run", ".", ".", "."), ("run", "missing"),
            ("run", str(self.root / "scripts/run.sh")),
        ]:
            with self.subTest(arguments=arguments):
                result, calls = self.invoke(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    def test_missing_pipeline_tool_is_detected_before_formatting(self):
        (self.bin / "hlint").unlink()
        result, calls = self.invoke("all")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hlint", result.stderr)
        self.assertEqual(calls, [])

    def test_failed_source_discovery_cleans_up_and_preserves_exit_code(self):
        finder = self.bin / "find"
        finder.write_text("#!/bin/sh\nexit 9\n", encoding="utf-8")
        finder.chmod(0o755)
        result, calls = self.invoke("format")
        self.assertEqual(result.returncode, 9, result.stderr)
        self.assertEqual(calls, [])
        self.assertEqual(list(self.scratch.iterdir()), [])

    def test_help_needs_no_development_tools(self):
        for name in ("stack", "python3", "stylish-haskell", "hlint"):
            (self.bin / name).unlink()
        result, calls = self.invoke("help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("format", result.stdout)
        self.assertIn("lint", result.stdout)
        self.assertEqual(calls, [])

    def test_individual_stack_commands_keep_their_existing_behavior(self):
        for command in ("build", "test", "clean", "run"):
            with self.subTest(command=command):
                result, calls = self.invoke(command)
                self.assertEqual(result.returncode, 0, result.stderr)
                stack_calls = [call["args"] for call in calls if call["name"] == "stack"]
                self.assertEqual(stack_calls, [["run", "hfm", "--"]] if command == "run" else [[command]])


@unittest.skipUnless(shutil.which("stylish-haskell"), "stylish-haskell is not installed")
class FormatterConfiguration(unittest.TestCase):
    def test_implicit_main_modules_can_be_formatted_repeatedly(self):
        configuration = Path(__file__).resolve().parents[1] / ".stylish-haskell.yaml"
        with tempfile.TemporaryDirectory(prefix="hfm-formatter-") as temporary:
            source = Path(temporary) / "Main.hs"
            source.write_text("main :: IO ()\nmain = pure ()\n", encoding="utf-8")
            for _ in range(2):
                result = subprocess.run(
                    ["stylish-haskell", "--config", str(configuration), "-i", str(source)],
                    text=True,
                    capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
