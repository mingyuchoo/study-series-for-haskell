# servant-t01-sqlite

Servant 기반 REST API + 웹 UI 서버로, SQLite를 데이터베이스로 사용하는 사용자 관리 애플리케이션입니다.

## 기술 스택

- **Haskell** (GHC2024, Stackage LTS-24.20)
- **Servant** - 타입 안전한 REST API 프레임워크
- **SQLite** (`sqlite-simple`) - 경량 데이터베이스
- **Lucid** - 타입 안전한 HTML 템플릿
- **Warp** - 고성능 HTTP 서버
- **Wai** - 정적 파일 서빙

## 프로젝트 구조

```
servant-t01-sqlite/
├── app/Main.hs            # 애플리케이션 진입점
├── src/Lib.hs             # API 정의, 핸들러, DB 로직, HTML 템플릿
├── test/Spec.hs           # 테스트
├── static/                # 정적 파일 (CSS, JS)
│   ├── css/
│   └── js/
├── docker/Dockerfile      # Docker 빌드 설정
├── package.yaml           # 프로젝트 의존성 설정
├── stack.yaml             # Stack 빌드 설정
└── Makefile               # 빌드/실행 자동화
```

## 빌드 및 실행

### 프로젝트 생성

```bash
stack new <project-name> mingyuchoo/new-template
```

### 빌드

```bash
stack build
# 또는
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

### 테스트

```bash
stack test --fast --file-watch --watch-all
# 또는
stack test --coverage --fast --file-watch --watch-all --haddock
# 또는
ghcid --command "stack ghci test/Spec.hs"
```

### 실행

```bash
stack run
```

서버가 시작되면 http://localhost:4000 에서 접속할 수 있습니다.

### Makefile 사용

```bash
make build       # 빌드
make test        # 테스트
make run         # 실행
make watch-test  # 테스트 감시 모드
make coverage    # 커버리지 포함 테스트
make ghcid       # ghcid 실행
```

## 웹 UI

루트 경로(`/`)에 접속하면 사용자 관리 웹 인터페이스를 제공합니다.

- 사용자 목록 조회
- 사용자 생성/수정/삭제 폼

## REST API

### 엔드포인트

| Method | Path              | Request Body  | Description          |
|--------|-------------------|---------------|----------------------|
| GET    | /users            | -             | 전체 사용자 조회     |
| POST   | /users            | `NewUser`     | 사용자 생성          |
| GET    | /users/:userId    | -             | 특정 사용자 조회     |
| PUT    | /users/:userId    | `User`        | 사용자 수정          |
| DELETE | /users/:userId    | -             | 사용자 삭제          |

### 데이터 모델

```json
// NewUser (생성 시)
{ "newUserName": "Alice" }

// User (수정 시)
{ "userId": 1, "userName": "Alice" }
```

### 응답 형식

생성(`POST`) 및 수정(`PUT`) 엔드포인트는 `Either ValidationError [User]` 타입을 반환합니다. Aeson의 기본 직렬화에 의해 다음과 같은 JSON 형식으로 응답됩니다:

```json
// 성공 시
{ "Right": [{ "userId": 1, "userName": "Alice" }] }

// 유효성 검증 실패 시
{ "Left": { "errorMessage": "Username must be at least 3 characters long" } }
```

### 유효성 검증

사용자 이름(`userName`)에 대해 다음 규칙이 적용됩니다:

- 빈 값 불가
- 3자 이상, 50자 이하
- 영문, 숫자, 공백, 밑줄(`_`), 하이픈(`-`)만 허용

### 사용 예시

#### 전체 사용자 조회
```bash
curl http://localhost:4000/users
```

#### 사용자 생성
```bash
curl -X POST http://localhost:4000/users \
  -H "Content-Type: application/json" \
  -d '{"newUserName": "Alice"}'
```

#### 특정 사용자 조회
```bash
curl http://localhost:4000/users/1
```

#### 사용자 수정
```bash
curl -X PUT http://localhost:4000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "userName": "Bob"}'
```

#### 사용자 삭제
```bash
curl -X DELETE http://localhost:4000/users/1
```

## Docker

```bash
make docker-build          # Docker 이미지 빌드
make docker-run            # Docker 컨테이너 실행 (포트 8000)
make docker-compose-up     # Docker Compose 실행
make docker-compose-down   # Docker Compose 중지
make docker-compose-logs   # Docker Compose 로그 확인
```

## References

- <https://marketsplash.com/tutorials/haskell/haskell-servant/>
- <https://docs.servant.dev/>
- <https://hackage.haskell.org/package/sqlite-simple>
