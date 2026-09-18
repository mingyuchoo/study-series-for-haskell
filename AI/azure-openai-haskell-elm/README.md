# OpenAI Haskell Agent

Full-stack application with Haskell backend and Elm frontend.

## Architecture

- **Backend**: Haskell with Servant (Onion Architecture)
- **Frontend**: Elm with Clean Architecture
- **Integration**: Frontend builds are served as static files by the backend

## Quick Start

### Prerequisites

- Stack (Haskell build tool)
- Elm 0.19.2 or higher
- Make

### Build and Run

```bash
# Build everything (frontend + backend)
make build

# Run the server
make run
```

The server will start on port 8000:
- Web UI: http://localhost:8000/
- API: http://localhost:8000/api/chat
- Health: http://localhost:8000/health
- Swagger UI: http://localhost:8000/swagger-ui
- OpenAPI JSON: http://localhost:8000/openapi.json

### Development

#### Frontend Development

```bash
cd frontend
# Build the Elm application
elm make src/Main.elm --output=public/elm.js

# Serve with a simple HTTP server
cd public
python3 -m http.server 8000
# or
npx http-server . -p 8000
```

For development with auto-reload, you can use `elm-live`:
```bash
bun install -g elm-live
elm-live src/Main.elm --open -- --output=public/elm.js
```

#### Backend Development

```bash
cd backend
make watch-test
```

### Build Process

The Makefile automatically:
1. Builds the frontend (Elm app with `--optimize` flag)
2. Copies frontend build (`elm.js` and `index.html`) to `backend/static/`
3. Builds the backend (Haskell)
4. Backend serves frontend from `/` and API from `/api`

### Project Structure

```
.
├── backend/              # Haskell backend
│   ├── src/             # Source code (Onion Architecture)
│   ├── test/            # Tests
│   └── static/          # Frontend build output (generated)
├── frontend/            # Elm frontend
│   ├── src/            # Source code (Clean Architecture)
│   │   ├── Main.elm                    # Application entry point
│   │   ├── Domain/                     # Business logic & entities
│   │   │   ├── Message.elm
│   │   │   └── ChatService.elm
│   │   ├── Application/                # Use cases
│   │   │   ├── ChatState.elm
│   │   │   └── ChatUseCase.elm
│   │   ├── Infrastructure/             # External dependencies
│   │   │   ├── Http/
│   │   │   │   ├── ChatApi.elm
│   │   │   │   └── Decoder.elm
│   │   │   └── Error.elm
│   │   └── Presentation/               # UI components
│   │       ├── View.elm
│   │       └── Components/
│   │           ├── Header.elm
│   │           ├── MessageList.elm
│   │           └── InputArea.elm
│   └── public/          # Static files & build output
├── docs/                # Architecture documentation
└── Makefile            # Build orchestration
```

## Available Make Commands

- `make build` - Build frontend and backend
- `make run` - Run the server
- `make test` - Run backend tests
- `make clean` - Clean all build artifacts
- `make frontend-build` - Build only frontend (optimized)
- `make frontend-clean` - Clean frontend build
- `make frontend-format` - Format Elm code
- `make docker-build` - Build Docker image
- `make docker-run` - Run in Docker
- `make docker-compose-up` - Start with Docker Compose
- `make docker-compose-down` - Stop Docker Compose

## API Endpoints

### POST /api/chat
Chat with the AI assistant.

**Request:**
```json
{
  "inputMessage": "Hello",
  "sessionId": "optional-uuid"
}
```

**Response:**
```json
{
  "outputMessage": "Response from AI",
  "outputSessionId": "uuid"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "UP",
  "version": "0.1.0.0",
  "uptime": 0,
  "timestamp": "2025-01-10T12:00:00Z"
}
```

## Frontend Architecture

The Elm frontend follows Clean Architecture principles with clear layer separation:

### Layer Dependencies
```
Presentation → Application → Domain ← Infrastructure
```

- **Domain**: Pure business logic with no external dependencies
- **Application**: Use cases that orchestrate domain logic
- **Infrastructure**: External integrations (HTTP API)
- **Presentation**: UI components and views

### Key Benefits

1. **Clear separation of concerns**: Each layer has a single responsibility
2. **Testability**: Layers can be tested independently
3. **Maintainability**: Changes are isolated to specific layers
4. **Extensibility**: Easy to add new features following the pattern
5. **Type safety**: Elm's type system enforces architectural boundaries

### Adding New Features

See `docs/FRONTEND_ARCHITECTURE_DIAGRAM.md` for examples of:
- Adding message editing functionality
- Creating new UI components
- Integrating new API endpoints

For detailed architecture documentation, see:
- `docs/FRONTEND_CLEAN_ARCHITECTURE_KO.md` - Clean Architecture guide
- `docs/FRONTEND_ARCHITECTURE_DIAGRAM.md` - Architecture diagrams and examples
- `docs/FRONTEND_IMPLEMENTATION_KO.md` - Implementation details
