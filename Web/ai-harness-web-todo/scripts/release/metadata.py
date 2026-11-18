import re


def package_version(sources: list[str]) -> str:
    versions = [
        re.findall(
            r"^version:\s*([0-9]+(?:\.[0-9]+)*)\s*$",
            source,
            re.MULTILINE | re.IGNORECASE,
        )
        for source in sources
    ]
    if not versions or any(len(matches) != 1 for matches in versions):
        raise ValueError("Every Cabal package must declare one numeric version")
    distinct = {matches[0] for matches in versions}
    if len(distinct) != 1:
        raise ValueError("Cabal package versions must agree before releasing")
    return distinct.pop()


def compiler_target(triple: str, system: str, machine: str) -> tuple[str, str]:
    systems = {"Linux": "linux", "Darwin": "macos", "Windows": "windows"}
    architectures = {
        "x86_64": "x64",
        "amd64": "x64",
        "aarch64": "arm64",
        "arm64": "arm64",
    }
    target_system = (
        "windows"
        if "mingw32" in triple
        else "macos"
        if "darwin" in triple
        else "linux"
        if "linux" in triple
        else None
    )
    target_architecture = architectures.get(triple.split("-", 1)[0].lower())
    if target_system is None or target_system != systems.get(system):
        raise ValueError(
            f"A native Linux, macOS or Windows compiler is required: {triple} on {system}"
        )
    if target_architecture is None or target_architecture != architectures.get(
        machine.lower()
    ):
        raise ValueError(
            f"Compiler architecture must match the host: {triple} on {machine}"
        )
    return target_system, target_architecture


def linux_libraries(listing: str) -> dict[str, str]:
    libraries = {}
    system_library = re.compile(
        r"lib(?:c|m|pthread|dl|rt|resolv|util|anl|BrokenLocale)\.so\."
    )
    for line in listing.splitlines():
        if "=> not found" in line:
            raise ValueError(f"Unresolved runtime dependency: {line.strip()}")
        match = re.match(r"\s*(\S+)\s+=>\s+(/.+?)\s+\(0x[0-9a-fA-F]+\)", line)
        if match and not system_library.match(match[1]):
            libraries[match[1]] = match[2]
    return libraries


def windows_libraries(listing: str) -> list[str]:
    return re.findall(
        r"^\s*DLL Name:\s*(\S+)\s*$", listing, re.MULTILINE | re.IGNORECASE
    )
