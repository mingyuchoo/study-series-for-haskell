# warp-t03-clean-archi

A Haskell web application demonstrating Clean Architecture principles with a User Management System. Built using Warp web server, SQLite database, and a RESTful API with an Elm 0.19.3 frontend.

## Architecture

This project follows Clean Architecture patterns with clear separation of concerns:

- **Domain Layer** (`src/Domain/`): Pure business entities and rules
  - `UserModel.hs`: Core User entity with JSON serialization
- **Application Layer** (`src/Application/`): Use case interfaces and business logic
  - `UserService.hs`: User management use cases
- **Infrastructure Layer** (`src/Infrastructure/`): External concerns
  - `Config/AppConfig.hs`: Application configuration
  - `Database/Connection.hs`: Database connection management
- **Adapters Layer** (`src/Adapters/`): Interface implementations
  - `Repository/UserRepositoryAdapter.hs`: SQLite repository implementation
  - `Web/UserWebAdapter.hs`: WAI web interface with REST API

## Features

- **RESTful API** for user management (CRUD operations)
- **Elm 0.19.3 Frontend** with pure state transitions and a separate HTTP adapter
- **SQLite Database** with automatic table creation
- **Clean Architecture** with dependency inversion
- **Docker Support** with multi-stage builds
- **Static File Serving** for web assets

### API Endpoints

- `GET /api/users` - List all users
- `GET /api/users/{id}` - Get user by ID
- `POST /api/users` - Create new user
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Delete user

### Static File Routes

- `GET /` - Serves `www/index.html`
- `GET /styles.css` - Serves `www/styles.css`
- `GET /elm.js` - Serves the compiled Elm application (`www/elm.js`)

### Web Interface

- User creation form with name input
- User list table with edit/delete actions
- Inline edit form with validation and preservation of input after failures
- Search by name or ID, explicit deletion confirmation, retryable errors
- Accessible status messages, keyboard controls, and responsive layouts
- DESIGN.md cream/coral/dark palette, serif headings, and token-based CSS

## Prerequisites

- [Stack](https://docs.haskellstack.org/en/stable/README/) (Haskell build tool)
- Node.js 22+ and npm; npm installs the pinned Elm 0.19.3 compiler and test tools
- [Docker](https://www.docker.com/) (optional, for containerized deployment)

## How to create a project

```bash
stack new <project-name> mingyuchoo/new-template
```

## How to build

### Elm frontend workspace

The root npm workspace owns `@warp/frontend` in `apps/frontend`:

- `src/Domain/User.elm`: pure name validation and directory filtering.
- `src/Application/Management.elm`: pure model/update logic and typed effect descriptions.
- `src/Infrastructure/UserApi.elm`: JSON and HTTP boundary for the existing REST API.
- `src/Presentation/`: HTML views; `src/Main.elm` wires the Elm runtime.
- `tests/`: deterministic domain/application unit tests.

The frontend uses Elm 0.19.3, elm/browser, elm/html, elm/http, and elm/json.
UI state and behavior live in Elm; the HTML shell only mounts the compiled app.
No shared package is needed yet; all Elm modules stay within this workspace.
`www/elm.js`, `elm-stuff`, and `node_modules` are generated and ignored.
The UI uses the local font fallback stacks specified by DESIGN.md.

```bash
npm ci
npm run build
npm test
npm run format:check
npx playwright install chromium
npm run test:e2e
npm run test:integration
```

Browser tests serve the real compiled frontend and substitute the HTTP boundary
with isolated fixtures; desktop, tablet, and mobile projects exercise CRUD,
validation, search, request failures, confirmation, and safe text rendering.
`npm run test:e2e` rebuilds Elm before testing. `npm run test:integration`
builds both applications, starts the real Warp executable with a temporary
SQLite database, and verifies CRUD through Chromium. It requires port 8000
to be free and removes its temporary database after stopping the server.

To run the application with its real Haskell API:

```bash
npm ci
npm run build
stack build
stack exec warp-t03-clean-archi-exe
```

Open `http://localhost:8000`. Rebuild Elm after editing its source. `make build`
and `make run` build the frontend automatically; `make frontend-e2e` builds it
and runs browser checks. Docker builds the frontend in a Node stage and copies
its output into the Warp image.

### Format, lint, build, test, and run

Install Stack and the development tools on your `PATH`:

```bash
stack install fourmolu hlint
```

Use a recent HLint version that supports `GHC2024`.

From Bash:

```bash
./scripts/run.sh
./scripts/run.sh --skip-run
./scripts/run.sh --help
```

From PowerShell:

```powershell
./scripts/run.ps1
./scripts/run.ps1 -SkipRun
./scripts/run.ps1 -Help
```

Both scripts resolve the project root from their own location. They format root-level
Haskell files and all Haskell files under `src`, `app`, and `test` in place using
`fourmolu.yaml`, run HLint, install/build/test the Elm workspace, build the Haskell application and tests, run the Haskell test suite, and
start `warp-t03-clean-archi-exe` at `http://localhost:8000`. Any failed command stops
the pipeline with a nonzero exit code. The skip-run option stops after testing;
otherwise, use Ctrl+C to stop the server.

The existing `Given Lib` test calls `appRunner`, which starts a persistent server;
that test must be changed to terminate before the pipeline can reach server startup.
Run `stack test --test-arguments=--skip=appRunner` for the terminating Haskell tests.
Use `npm run test:integration` for the isolated, terminating real-server CRUD check.

### Build only

```bash
npm ci
npm run build
stack build
# or
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

## How to test

```bash
# Run tests once
stack test --fast

# Watch mode for continuous testing
stack test --fast --file-watch --watch-all

# With coverage report
stack test --coverage --fast --file-watch --watch-all --haddock

# Using ghcid for fast feedback
ghcid --command "stack ghci test/Spec.hs"
```

## How to run

```bash
# Run the application
stack run

# The server will start on http://localhost:8000
```

## Using Makefile

You can also use the provided `Makefile` for common tasks:

```bash
# Build and run everything
make all

# Individual commands
make clean
make setup
make format
make build
make test
make run
make coverage
make watch-test
make watch-coverage
make ghcid
make install

# Docker operations
make docker-build
make docker-run
make docker-compose-up
make docker-compose-down
make docker-compose-logs
```

## Docker Deployment

### Single Container

```bash
# Build and run with Docker
make docker-build
make docker-run

# Or manually
docker build --build-arg PROJECT_NAME=warp-t03-clean-archi -t warp-t03-clean-archi:latest -f docker/Dockerfile .
docker run -it --rm -p 8000:8000 -v $(PWD)/data:/app/data warp-t03-clean-archi:latest
```

### Docker Compose

```bash
# Start with docker-compose
make docker-compose-up

# View logs
make docker-compose-logs

# Stop services
make docker-compose-down
```

## Project Structure

```
├── app/
│   └── Main.hs                              # Application entry point
├── src/
│   ├── Domain/
│   │   └── UserModel.hs                     # User entity with JSON serialization
│   ├── Application/
│   │   └── UserService.hs                   # Use case interfaces (CRUD)
│   ├── Infrastructure/
│   │   ├── Config/
│   │   │   └── AppConfig.hs                 # Port and DB path configuration
│   │   └── Database/
│   │       └── Connection.hs                # SQLite connection and table init
│   ├── Adapters/
│   │   ├── Repository/
│   │   │   └── UserRepositoryAdapter.hs     # SQLite repository implementation
│   │   └── Web/
│   │       └── UserWebAdapter.hs            # WAI web interface with routing
│   └── Lib.hs                               # Application orchestration
├── test/
│   └── Spec.hs                              # Test suite (hspec)
├── apps/frontend/                           # Elm application workspace
│   ├── elm.json
│   ├── src/                                 # Domain, application, adapters, presentation
│   └── tests/
├── tests/browser/                           # Frontend browser tests
├── tests/integration/                       # Real Warp and Elm CRUD check
├── www/                                     # Web frontend assets
│   ├── index.html
│   ├── styles.css
│   └── elm.js                               # Generated Elm bundle
├── docker/
│   ├── Dockerfile                           # Multi-stage Docker build
│   └── docker-compose.yaml
└── Makefile                                 # Build automation
```

## Dependencies

Key Haskell packages used:
- `warp` - HTTP server
- `wai` - Web Application Interface
- `http-types` - HTTP status codes and method constants
- `sqlite-simple` - SQLite database bindings
- `aeson` - JSON parsing/encoding
- `flow` - Function composition utilities (`<|` operator)
- `bytestring` / `text` - String handling

## Development

The application runs on port 8000 by default. The SQLite database (`users.db`) is created automatically in the project root.

For development with auto-reload:
```bash
make watch-test  # Continuous testing
ghcid --command "stack ghci test/Spec.hs"  # Fast compilation feedback
```
