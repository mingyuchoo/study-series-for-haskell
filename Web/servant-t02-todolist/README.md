# servant-t02-todolist

Servant 프레임워크 기반의 Todo 관리 웹 애플리케이션입니다. SQLite 데이터베이스와 Lucid HTML 템플릿을 사용하며, Clean Architecture(Onion Architecture) 패턴을 적용했습니다.

## 프로젝트 구조

```
servant-t02-todolist/
├── app/Main.hs                                    # 애플리케이션 진입점
├── src/
│   ├── Lib.hs                                     # 앱 설정, API 결합
│   ├── Domain/Repositories/
│   │   ├── Entities/Todo.hs                       # 데이터 모델, 유효성 검사
│   │   └── TodoRepository.hs                      # 리포지토리 인터페이스
│   ├── Application/UseCases/TodoUseCases.hs       # 유스케이스 (비즈니스 로직)
│   ├── Infrastructure/Repositories/
│   │   ├── DatabaseRepository.hs                  # DB 연결 관리
│   │   ├── SQLiteTodoRepository.hs                # SQLite 구현체
│   │   └── Operations/DatabaseOperations.hs       # DB 작업
│   └── Presentation/
│       ├── API/TodoAPI.hs                         # REST API 핸들러
│       ├── Web/WebAPI.hs                          # 웹 인터페이스 핸들러
│       ├── Web/Templates.hs                       # Lucid HTML 템플릿
│       └── Middleware/LoggingMiddleware.hs         # 요청/응답 로깅
├── test/Spec.hs                                   # 테스트 스위트
├── static/                                        # CSS, JS, 정적 파일
├── docker/Dockerfile                              # Docker 빌드
└── docs/architecture.mmd                          # 아키텍처 다이어그램
```

## 데이터 모델

| 필드      | 타입     | 설명                                         |
|-----------|----------|----------------------------------------------|
| todoId    | Int      | 자동 증가 기본 키                            |
| todoTitle | Text     | 할 일 제목 (3~50자)                          |
| createdAt | UTCTime  | 생성 시각                                    |
| priority  | Priority | Low, Medium, High (클릭으로 순환 전환)       |
| status    | Status   | Todo, Doing, Done (클릭으로 순환 전환)       |

## 빌드 및 실행

```bash
# 빌드
make build
# 또는
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"

# 실행 (http://localhost:8000)
make run
# 또는
stack run

# 테스트
make test

# 테스트 (watch 모드)
make watch-test

# 테스트 커버리지
make coverage

# 코드 포맷팅
make format
```

## Docker

```bash
# Docker 이미지 빌드
make docker-build

# Docker 컨테이너 실행 (포트 8000, 데이터 볼륨 마운트)
make docker-run

# Docker Compose
make docker-compose-up
make docker-compose-down
make docker-compose-logs
```

## REST API

서버 실행 후 사용 가능한 엔드포인트 (기본: http://localhost:8000):

| Method | Path               | Description           |
|--------|--------------------|-----------------------|
| GET    | /                  | 웹 인터페이스 (HTML)  |
| GET    | /api/todos         | 전체 Todo 조회        |
| POST   | /api/todos         | 새 Todo 생성          |
| GET    | /api/todos/:id     | 특정 Todo 조회        |
| PUT    | /api/todos/:id     | Todo 수정             |
| DELETE | /api/todos/:id     | Todo 삭제             |

### 사용 예시

```bash
# 전체 Todo 조회
curl http://localhost:8000/api/todos

# 새 Todo 생성 (priority: Medium, status: Todo가 기본값)
curl -X POST http://localhost:8000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"newTodoTitle": "장보기"}'

# 특정 Todo 조회
curl http://localhost:8000/api/todos/1

# Todo 수정
curl -X PUT http://localhost:8000/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"todoId": 1, "todoTitle": "장보기 완료", "createdAt": "2026-01-01T00:00:00Z", "priority": "High", "status": "DoneStatus"}'

# Todo 삭제
curl -X DELETE http://localhost:8000/api/todos/1
```

## 웹 인터페이스

브라우저에서 http://localhost:8000 접속 시 웹 UI를 사용할 수 있습니다.

- Todo 생성/수정/삭제
- Priority 클릭으로 순환 전환 (Low → Medium → High → Low)
- Status 클릭으로 순환 전환 (Todo → Doing → Done → Todo)
- 상대 시간 표시 (예: "2분 전")

## 기술 스택

- **언어**: Haskell (GHC2024, Stack LTS-24.20)
- **웹 프레임워크**: Servant + Warp
- **데이터베이스**: SQLite (sqlite-simple)
- **HTML 템플릿**: Lucid
- **JSON**: Aeson
- **테스트**: Hspec, Doctest

## References

- <https://marketsplash.com/tutorials/haskell/haskell-servant/>
