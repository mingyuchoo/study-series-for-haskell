#!/usr/bin/env python3
"""Regression tests for the boundary checker using isolated workspace fixtures."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("architecture", Path(__file__).with_name("check-architecture.py"))
architecture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(architecture)


class Boundaries(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        folders = [f"packages/{name}" for name in architecture.LAYERS] + ["apps/hfm"]
        (self.root / "stack.yaml").write_text("packages:\n" + "".join(f"- {path}\n" for path in folders))
        (self.root / "cabal.project").write_text("packages:\n" + "".join(f"  {path}\n" for path in folders))
        for path in folders:
            folder = self.root / path
            (folder / "src").mkdir(parents=True)
            (folder / "package.yaml").write_text("dependencies:\n- base\nlibrary:\n  source-dirs: src\n")
        self.workflow = self.root / "packages/hfm-application/src/Workflow.hs"

    def test_accepts_pure_requests(self):
        self.workflow.write_text("module Workflow where\nimport Hfm.Application.Program\nimport Hfm.Application.Error\n")
        self.assertEqual(architecture.check(self.root), [])

    def test_rejects_adapter_dependency(self):
        path = self.root / "packages/hfm-application/package.yaml"
        path.write_text("dependencies:\n- base\n- hfm-infrastructure\nlibrary:\n")
        self.assertTrue(any("forbidden dependency" in error for error in architecture.check(self.root)))

    def test_rejects_framework_import_across_lines(self):
        self.workflow.write_text("import\n qualified Graphics.Vty as V\n")
        self.assertTrue(any("effect/framework module" in error for error in architecture.check(self.root)))

    def test_rejects_executing_ports_in_pure_plans(self):
        for imported in ("Hfm.Application.Effects.Ports (FileSystem)",
                         "qualified Hfm.Application.Effects.Ports as P",
                         "Hfm.Application.Effects.Ports (Processes)"):
            with self.subTest(imported=imported):
                self.workflow.write_text(f"import {imported}\n")
                self.assertTrue(any("executable ports" in error for error in architecture.check(self.root)))
        self.workflow.write_text("import Hfm.Application.Effects.Runtime\n")
        self.assertTrue(any("effect interpreter" in error for error in architecture.check(self.root)))

    def test_only_effect_modules_can_execute_ports(self):
        effects = self.workflow.parent / "Hfm/Application/Effects"
        effects.mkdir(parents=True)
        (effects / "Runtime.hs").write_text("import Hfm.Application.Effects.Ports\n")
        self.assertEqual(architecture.check(self.root), [])
        (self.workflow.parent / "Runtime.hs").write_text("import Hfm.Application.Effects.Ports\n")
        self.assertTrue(any("executable ports" in error for error in architecture.check(self.root)))

    def test_rejects_effect_dependencies_in_conditional_and_library_sections(self):
        path = self.root / "packages/hfm-application/package.yaml"
        for section in ("when:\n- condition: os(windows)\n  dependencies:\n  - process\n",
                        "library:\n  dependencies:\n  - directory\n"):
            with self.subTest(section=section):
                path.write_text("dependencies:\n- base\n" + section)
                self.assertTrue(any("effect/framework dependency" in error for error in architecture.check(self.root)))

    def test_rejects_concrete_io_in_effect_interfaces_too(self):
        effects = self.workflow.parent / "Hfm/Application/Effects"
        effects.mkdir(parents=True)
        (effects / "Ports.hs").write_text("port :: IO ()\n")
        self.assertTrue(any("concrete IO" in error for error in architecture.check(self.root)))

    def test_adapters_cannot_depend_on_each_other(self):
        for package, imported in (("hfm-tui", "Hfm.Infrastructure.Ports"),
                                  ("hfm-infrastructure", "Hfm.Tui.App")):
            with self.subTest(package=package):
                source = self.root / f"packages/{package}/src/Adapter.hs"
                source.write_text(f"import {imported}\n")
                self.assertTrue(any("forbidden" in error for error in architecture.check(self.root)))
                source.unlink()

    def test_rejects_workspace_drift(self):
        (self.root / "cabal.project").write_text("packages:\n  packages/hfm-domain\n")
        self.assertTrue(any("workspace mismatch" in error for error in architecture.check(self.root)))

    def test_rejects_effect_dependency_without_an_import(self):
        path = self.root / "packages/hfm-domain/package.yaml"
        path.write_text("dependencies:\n- base\n- directory\nlibrary:\n")
        self.assertTrue(any("effect/framework dependency directory" in error for error in architecture.check(self.root)))


if __name__ == "__main__":
    unittest.main()
