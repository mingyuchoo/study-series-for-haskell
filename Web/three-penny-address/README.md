# ThreepennyAddress

ThreepennyAddress is an address book application with an Elm 0.19.3 frontend
and a Haskell backend. It runs a local web UI on `http://localhost:8023` and stores
contacts in a JSON file.

## Features

- Add, edit, delete, and search contacts
- Store name, phone, email, and address fields
- Validate required names, email format, and phone format
- Persist contacts to `contacts.json`
- Run from source, Docker, or native installer packages

## Requirements

- Stack
- GHC 9.10.3 through Stack resolver `lts-24.40`
- GNU Make
- [Elm 0.19.3](https://github.com/elm/compiler/releases/tag/0.19.3) for local frontend builds

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

To compile the frontend and invoke Stack directly:

```bash
make frontend
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

The application starts the Haskell server at:

```text
http://localhost:8023
```

The app reads and writes `contacts.json` in the current working directory.
Set `ADDRESS_BOOK_CONTACTS_FILE` to use a different file. The server listens on
loopback by default. Set `ADDRESS_BOOK_BIND_ADDRESS` to override that address.
The server loads frontend assets from `static/`. Set `ADDRESS_BOOK_STATIC_DIRECTORY`
to serve them from a different directory.

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
make format           # Format packages and apps with stylish-haskell
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
into `/app/data`. The container stores contacts in `data/contacts.json` on the host.

Docker Compose helpers:

```bash
make docker-compose-up
make docker-compose-logs
make docker-compose-down
```

## Project Layout

| Workspace package | Responsibility |
| --- | --- |
| `packages/address-book-domain` | Pure contact models, validation, search, and address book changes |
| `packages/address-book-application` | Contact use cases and the repository port |
| `packages/address-book-json` | JSON format compatibility and file persistence |
| `apps/address-book-elm` | Elm contact list, forms, and browser interaction |
| `apps/threepenny-address` | HTTP adapter, static asset serving, and executable wiring |

Elm communicates with the HTTP adapter through a same-origin JSON API. The
HTTP adapter uses the application and domain packages. The JSON adapter
implements the application repository port. The executable connects both adapters
at startup. `make build` compiles Elm into `static/elm.js` and builds the Haskell
workspace with Stack.

The JSON adapter preserves the `contacts` and `nextId` fields in existing
`contacts.json` files. It serializes writes through the repository instance
shared by the server and replaces the file after encoding succeeds.

## Notes

- The executable name is `ThreepennyAddress-exe`.
- The package version is `0.1.0.0`.
- The package license is BSD-3-Clause.
- Tests currently cover validation, search, contact service behavior, and JSON
  repository file operations.
