# ThreepennyAddress

ThreepennyAddress is a Haskell address book application built with
Threepenny-GUI. It runs a local web UI on `http://localhost:8023` and stores
contacts in a JSON file.

## Features

- Add, edit, delete, and search contacts
- Store name, phone, email, and address fields
- Validate required names, email format, and phone format
- Persist contacts to `contacts.json`
- Run from source, Docker, or native installer packages

## Requirements

- Stack
- GHC 9.10.3 through Stack resolver `lts-24.21`
- GNU Make

Optional tools:

- `stylish-haskell` for `make format`
- `ghcid` for `make ghcid`
- Docker for Docker targets
- `fpm` on Linux to build `.deb` and `.rpm`
- `hdiutil` on macOS to build `.dmg`
- WiX v4 CLI (`wix`) on Windows to build `.msi`

## Build And Test

```bash
make build
make test
```

Equivalent Stack commands:

```bash
stack build --fast
stack test --fast
```

Run the complete local verification flow:

```bash
make all
```

## Run

```bash
make run
```

The application starts a Threepenny server at:

```text
http://localhost:8023
```

The app reads and writes `contacts.json` in the current working directory.

Script wrappers are also available:

```bash
scripts/run.sh
```

On Windows:

```powershell
scripts\run.ps1
```

Both wrappers run `make build`, `make test`, and then `make run`.

## Development Commands

```bash
make deps             # Build dependencies
make clean            # Clean Stack and dist artifacts
make coverage         # Run tests with coverage
make watch-test       # Run tests in watch mode
make watch-coverage   # Run coverage in watch mode
make ghcid            # Start ghcid with stack ghci
make format           # Format src, app, and test with stylish-haskell
```

## Release Packages

Build the native installer for the current platform:

```bash
scripts/release.sh
```

On Windows:

```powershell
scripts\release.ps1
```

The release scripts run:

```bash
make build
make test
make release
```

Generated artifacts are written to `dist/release`.

Platform outputs:

- Linux: `.deb` and `.rpm`
- macOS: `.dmg`
- Windows: `.msi`

Linux packages install the application under `/opt/ThreepennyAddress`, add a
launcher at `/usr/local/bin/ThreepennyAddress`, and register a desktop entry at
`/usr/share/applications/threepennyaddress.desktop`. The desktop launcher starts
the local server in the background and opens `http://localhost:8023` with
`xdg-open`.

Linux desktop runtime paths:

- Data: `~/.local/share/ThreepennyAddress`
- Log: `~/.local/state/ThreepennyAddress/app.log`

## Docker

Build and run with Docker:

```bash
make docker-build
make docker-run
```

`make docker-run` exposes the GUI port as `8023:8023` and mounts local `data/`
into `/app/data`.

Docker Compose helpers:

```bash
make docker-compose-up
make docker-compose-logs
make docker-compose-down
```

## Project Layout

```text
app/Main.hs                    Executable entrypoint
src/GUI/Main.hs                Threepenny GUI setup and event handling
src/Models/                    Contact and application state models
src/Services/                  Contact, validation, search, and persistence logic
test/Spec.hs                   Hspec test entrypoint
scripts/run.sh                 Linux/macOS build-test-run wrapper
scripts/run.ps1                Windows build-test-run wrapper
scripts/release.sh             Linux/macOS native package builder
scripts/release.ps1            Windows MSI package builder
docker/                        Dockerfile and Compose file
static/index.html              Static HTML shell for Threepenny
```

## Notes

- The executable name is `ThreepennyAddress-exe`.
- The package version is `0.1.0.0`.
- The package license is BSD-3-Clause.
- Tests currently cover validation, search, contact service behavior, and JSON
  repository file operations.
