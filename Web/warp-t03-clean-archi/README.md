# warp-t03-clean-archi

A Haskell web application demonstrating Clean Architecture principles with a User Management System. Built using Warp web server, SQLite database, and a RESTful API with a web frontend.

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
- **Web Frontend** with interactive user interface
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
- `GET /script.js` - Serves `www/script.js`

### Web Interface

- User creation form with name input
- User list table with edit/delete actions
- Inline edit form for updating users
- Toast-style success/error notifications
- Responsive 2-column grid layout

## Prerequisites

- [Stack](https://docs.haskellstack.org/en/stable/README/) (Haskell build tool)
- [Docker](https://www.docker.com/) (optional, for containerized deployment)

## How to create a project

```bash
stack new <project-name> mingyuchoo/new-template
```

## How to build

```bash
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
├── www/                                     # Web frontend assets
│   ├── index.html
│   ├── styles.css
│   └── script.js
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
