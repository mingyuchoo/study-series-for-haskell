import os
import subprocess
from pathlib import Path


def run_command(
    arguments: list[str | Path],
    *,
    cwd: Path,
    capture: bool = False,
    env: dict[str, str] | None = None,
) -> str:
    command = [str(argument) for argument in arguments]
    print("+ " + subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        check=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else ""


def runtime_environment() -> dict[str, str]:
    environment = dict(os.environ)
    for name in ("LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH"):
        environment.pop(name, None)
    return environment
