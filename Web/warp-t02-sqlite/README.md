# warp-t02-sqlite

Warp 웹 서버와 SQLite를 사용한 사용자 관리 REST API 애플리케이션입니다.

## 개요

- **웹 프레임워크**: Warp (WAI 기반 HTTP 서버)
- **데이터베이스**: SQLite (`sqlite-simple`)
- **직렬화**: Aeson (JSON)
- **언어 표준**: GHC2024
- **Resolver**: LTS 24.20
- **포트**: 4000

## 프로젝트 구조

```
.
├── app/Main.hs          # 애플리케이션 진입점
├── src/
│   ├── Lib.hs           # Warp 서버 및 라우팅 로직
│   └── Database.hs      # SQLite DB 초기화 및 CRUD 함수
├── test/Spec.hs         # 테스트
├── www/
│   ├── index.html       # 사용자 관리 웹 UI
│   ├── styles.css       # 스타일시트
│   └── script.js        # 프론트엔드 스크립트
├── package.yaml         # 패키지 설정
├── stack.yaml           # Stack 설정 (Docker 지원 포함)
└── Makefile             # 빌드/실행 자동화
```

## API 엔드포인트

| 메서드   | 경로                | 설명              |
|----------|---------------------|-------------------|
| `GET`    | `/`                 | 웹 UI (index.html)|
| `GET`    | `/api/users`        | 전체 사용자 조회  |
| `GET`    | `/api/users/:id`    | 사용자 단건 조회  |
| `POST`   | `/api/users`        | 사용자 생성       |
| `PUT`    | `/api/users/:id`    | 사용자 수정       |
| `DELETE` | `/api/users/:id`    | 사용자 삭제       |

## 사용 방법

### 프로젝트 생성

```bash
stack new <project-name> mingyuchoo/new-template
```

### 빌드

```bash
make build
# 또는
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

### 테스트

```bash
make test
# Watch 모드
make watch-test
# 커버리지 포함
make coverage
```

### 실행

```bash
make run
# 또는
stack run
```

실행 후 브라우저에서 `http://localhost:4000` 으로 접속하면 사용자 관리 웹 UI를 사용할 수 있습니다.

### Docker

```bash
# Docker 이미지 빌드 및 실행
make docker-run

# Docker Compose
make docker-compose-up
make docker-compose-down
```
