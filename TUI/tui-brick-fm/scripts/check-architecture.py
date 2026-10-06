#!/usr/bin/env python3
"""Check workspace registration, dependency direction, and the pure-plan boundary."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LAYERS = {
    "hfm-domain": {"Domain"},
    "hfm-application": {"Domain", "Application"},
    "hfm-infrastructure": {"Domain", "Application", "Infrastructure"},
    "hfm-tui": {"Domain", "Application", "Tui"},
}
LOCAL_PACKAGES = {
    "hfm-domain": set(),
    "hfm-application": {"hfm-domain"},
    "hfm-infrastructure": {"hfm-domain", "hfm-application"},
    "hfm-tui": {"hfm-domain", "hfm-application"},
    "hfm": set(LAYERS),
}
INNER_DEPENDENCIES = {
    "hfm-domain": {"base", "text", "vector", "filepath"},
    "hfm-application": {"base", "hfm-domain", "text", "bytestring", "filepath", "mtl", "transformers"},
}
INNER_FORBIDDEN = (
    "Brick", "Graphics.Vty", "System.Directory", "System.IO", "System.Posix",
    "System.Environment", "Data.Yaml", "Control.Monad.IO.Class", "System.Process", "GHC.IO",
)


def uncomment(source):
    return re.sub(r"--[^\n]*|\{-.*?-\}", "", source, flags=re.DOTALL)


def check(root):
    violations = []
    workspace = {f"packages/{name}" for name in LAYERS} | {"apps/hfm"}
    for filename in ("stack.yaml", "cabal.project"):
        paths = set(re.findall(r"^\s*-?\s*((?:packages|apps)/[\w-]+)\s*$", (root / filename).read_text(), re.MULTILINE))
        if paths != workspace:
            violations.append(f"{filename} workspace mismatch: {sorted(paths ^ workspace)}")

    for package, local_allowed in LOCAL_PACKAGES.items():
        folder = root / ("apps" if package == "hfm" else "packages") / package
        manifest = (folder / "package.yaml").read_text()
        # Inspect production dependencies only; test suites may use fixtures/frameworks.
        production = manifest.split("tests:", 1)[0]
        dependencies = set(re.findall(r"^[ \t]*- ([a-z][\w-]*)(?:[ \t].*)?$", production, re.MULTILINE))
        for dependency in dependencies & set(LOCAL_PACKAGES) - local_allowed:
            violations.append(f"{package} has forbidden dependency {dependency}")
        if package in INNER_DEPENDENCIES:
            # Read just the top-level dependency list, excluding ghc options and module lists.
            block = production.split("dependencies:\n", 1)[1].split("\nlibrary:", 1)[0]
            declared = set(re.findall(r"^- ([a-z][\w-]*)", block, re.MULTILINE))
            for dependency in declared - INNER_DEPENDENCIES[package]:
                violations.append(f"{package} has effect/framework dependency {dependency}")

        source_dir = folder / ("app" if package == "hfm" else "src")
        for path in source_dir.rglob("*.hs"):
            code = uncomment(path.read_text())
            imports = re.findall(r'^\s*import\s+(?:qualified\s+)?(?:"[^"]+"\s+)?([\w.]+)', code, re.MULTILINE)
            label = str(path.relative_to(root))
            allowed = set().union(*LAYERS.values()) if package == "hfm" else LAYERS[package]
            pure_plan = package == "hfm-application" and path.name not in {"Ports.hs", "UseCases.hs"}
            for module in imports:
                if module.startswith("Hfm.") and module.split(".")[1] not in allowed:
                    violations.append(f"{label} imports forbidden {module}")
                if package in INNER_DEPENDENCIES and any(module == p or module.startswith(p + ".") for p in INNER_FORBIDDEN):
                    violations.append(f"{label} imports effect/framework module {module}")
                if pure_plan and module == "Hfm.Application.UseCases":
                    violations.append(f"{label} imports the effect interpreter")
            if package in INNER_DEPENDENCIES and re.search(r"\b(IO|unsafePerformIO|unsafeInterleaveIO|foreign)\b", code):
                violations.append(f"{label} contains concrete IO or FFI")
            if pure_plan and re.search(r"\bFileSystem\b", code):
                violations.append(f"{label} accesses executable ports instead of describing requests")
    return violations


def main():
    violations = check(ROOT)
    if violations:
        print("\n".join(violations), file=sys.stderr)
        return 1
    print("Architecture boundaries passed: pure plans -> port interpreter; domain <- application <- adapters <- composition root")
    return 0


if __name__ == "__main__":
    sys.exit(main())
