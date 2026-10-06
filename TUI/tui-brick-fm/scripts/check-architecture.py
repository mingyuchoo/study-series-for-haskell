#!/usr/bin/env python3
"""Enforce workspace dependency direction and keep inner layers free of IO adapters."""
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
}
INNER_FORBIDDEN = ("Brick", "Graphics.Vty", "System.Directory", "System.IO", "System.Posix", "System.Environment", "Data.Yaml", "Control.Monad.IO.Class", "System.Process", "GHC.IO")
violations = []
for package, allowed in LAYERS.items():
    folder = ROOT / "packages" / package
    manifest = (folder / "package.yaml").read_text()
    dependencies = set(re.findall(r"^- (hfm-[\w-]+)\s*$", manifest, re.MULTILINE))
    for dependency in dependencies - LOCAL_PACKAGES[package]:
        violations.append(f"{package} has forbidden dependency {dependency}")
    for path in (folder / "src").rglob("*.hs"):
        source = path.read_text()
        imports = re.findall(r"^import\s+(?:qualified\s+)?([\w.]+)", source, re.MULTILINE)
        for module in imports:
            if module.startswith("Hfm.") and module.split(".")[1] not in allowed:
                violations.append(f"{path.relative_to(ROOT)} imports forbidden {module}")
            if package in {"hfm-domain", "hfm-application"} and any(module == p or module.startswith(p + ".") for p in INNER_FORBIDDEN):
                violations.append(f"{path.relative_to(ROOT)} imports effect/framework module {module}")
        if package in {"hfm-domain", "hfm-application"}:
            code = re.sub(r"--[^\n]*|\{-.*?-\}", "", source, flags=re.DOTALL)
            if re.search(r"\b(IO|unsafePerformIO|unsafeInterleaveIO|foreign)\b", code):
                violations.append(f"{path.relative_to(ROOT)} contains concrete IO or FFI")
if violations:
    print("\n".join(violations), file=sys.stderr)
    sys.exit(1)
print("Architecture boundaries passed: domain <- application <- adapters <- composition root")
