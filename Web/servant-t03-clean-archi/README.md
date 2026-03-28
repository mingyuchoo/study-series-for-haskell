# servant-t03-clean-archi

Haskell Servant 기반 Todo 관리 웹 애플리케이션으로, Clean Architecture(Onion Architecture)를 적용한 프로젝트입니다.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Presentation (API, Web, Middleware)             │
│  ┌───────────────────────────────────────────┐  │
│  │ Application (UseCases)                    │  │
│  │  ┌─────────────────────────────────────┐  │  │
│  │  │ Domain (Entities, Repository I/F)   │  │  │
│  │  └─────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────┘  │
│ Infrastructure (SQLite, DatabaseOperations)      │
└─────────────────────────────────────────────────┘
```

### Project Structure

```
src/
├── Lib.hs                                    -- App entry, WAI server setup (port 8000)
├── Domain/
│   └── Repositories/
│       ├── Entities/
│       │   └── Todo.hs                       -- Todo, NewTodo, Priority, Status types
│       └── TodoRepository.hs                 -- Repository interface (typeclass)
├── Application/
│   └── UseCases/
│       └── TodoUseCases.hs                   -- Use case orchestration
├── Infrastructure/
│   └── Repositories/
│       ├── DatabaseRepository.hs             -- Database abstraction
│       ├── SQLiteTodoRepository.hs           -- SQLite implementation
│       └── Operations/
│           └── DatabaseOperations.hs         -- DB initialization & migration
└── Presentation/
    ├── API/
    │   └── TodoAPI.hs                        -- REST API handlers
    ├── Web/
    │   ├── WebAPI.hs                         -- Web page routing & static files
    │   └── Templates.hs                      -- Lucid HTML templates
    └── Middleware/
        └── LoggingMiddleware.hs              -- HTTP request/response logging
```

### Domain Model

| Field       | Type     | Description                               |
|-------------|----------|-------------------------------------------|
| `todoId`    | Int      | Primary key (auto-increment)              |
| `todoTitle` | Text     | Title (3-50 characters)                   |
| `createdAt` | UTCTime  | Auto-generated timestamp                  |
| `priority`  | Priority | Low / Medium / High (default: Medium)     |
| `status`    | Status   | TodoStatus / DoingStatus / DoneStatus     |

### Tech Stack

- **Language**: Haskell (GHC2024)
- **Web Framework**: Servant
- **Database**: SQLite (`haskell_todo.db`)
- **HTML Templating**: Lucid
- **Static Files**: WAI App Static
- **Build Tool**: Stack

## How to create a project

```bash
stack new <project-name> mingyuchoo/new-template
```

## How to build

```bash
make build
# or
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

## How to test

```bash
make test
# or watch mode
make watch-test
# or with coverage
make coverage
# or with ghcid
make ghcid
```

## How to run

```bash
make run
# or
stack run
```

서버가 시작되면 http://localhost:8000 에서 웹 UI에 접근할 수 있습니다.

## Docker

```bash
# Docker 빌드 및 실행
make docker-run

# Docker Compose 사용
make docker-compose-up
make docker-compose-down
make docker-compose-logs
```

## REST API

| Method | Path               | Description      |
|--------|--------------------|------------------|
| GET    | /api/todos         | 전체 Todo 조회    |
| POST   | /api/todos         | 새 Todo 생성      |
| GET    | /api/todos/:id     | ID로 Todo 조회    |
| PUT    | /api/todos/:id     | ID로 Todo 수정    |
| DELETE | /api/todos/:id     | ID로 Todo 삭제    |

### Usage Examples

#### 전체 Todo 조회
```bash
curl http://localhost:8000/api/todos
```

#### 새 Todo 생성
```bash
curl -X POST http://localhost:8000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"newTodoTitle": "Buy groceries"}'
```

#### ID로 Todo 조회
```bash
curl http://localhost:8000/api/todos/1
```

#### ID로 Todo 수정
```bash
curl -X PUT http://localhost:8000/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"todoId": 1, "todoTitle": "Updated title", "createdAt": "2025-01-01T00:00:00Z", "priority": "High", "status": "DoingStatus"}'
```

#### ID로 Todo 삭제
```bash
curl -X DELETE http://localhost:8000/api/todos/1
```

## Web UI

| Method | Path       | Description                          |
|--------|------------|--------------------------------------|
| GET    | /          | 메인 페이지 (Todo 폼 + 목록)          |
| GET    | /static/*  | 정적 파일 (CSS, JS, favicon)          |

## Makefile Targets

| Target               | Description                           |
|----------------------|---------------------------------------|
| `make all`           | clean, setup, build, test, run        |
| `make clean`         | Stack clean                           |
| `make setup`         | Stack setup + 의존성 설치               |
| `make build`         | 프로젝트 빌드                           |
| `make test`          | 테스트 실행                             |
| `make coverage`      | 커버리지 리포트 생성                     |
| `make watch-test`    | 파일 변경 감지 테스트                    |
| `make ghcid`         | ghcid로 테스트 감시                     |
| `make run`           | 서버 실행                               |
| `make format`        | stylish-haskell 포맷팅                 |
| `make docker-run`    | Docker 빌드 + 실행                     |
| `make docker-compose-up`   | Docker Compose 실행              |
| `make docker-compose-down` | Docker Compose 중지              |

## References

- <https://marketsplash.com/tutorials/haskell/haskell-servant/>
