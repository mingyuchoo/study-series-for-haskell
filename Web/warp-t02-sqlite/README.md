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

### 전체 개발 작업 실행

`stack`, `fourmolu`, `hlint`를 설치하고 `PATH`에 등록한 뒤 실행합니다.
Windows에서는 PowerShell도 필요합니다.

```bash
./scripts/run.sh
```

```powershell
.\scripts\run.ps1
```

두 스크립트는 프로젝트 루트로 이동한 뒤 다음 작업을 순서대로 수행합니다.

1. Fourmolu와 `fourmolu.yaml`로 루트 및 `app`, `src`, `test`의 Haskell 파일 포맷팅
2. HLint로 같은 파일 린팅
3. `stack build`
4. `stack test`
5. `stack exec warp-t02-sqlite-exe`로 서버 실행

포맷팅은 파일을 직접 수정합니다. 필요한 도구가 없거나 어느 단계든 실패하면 즉시
중단하고 실패 종료 코드를 반환합니다. 스크립트에 전달한 인수는 실행 파일로 전달합니다.
서버 주소는 `http://localhost:4000`이며 `Ctrl+C`로 종료합니다.

현재 `stack.yaml`의 `11,1: docker:` 및 `12: enable: false` 부분에는 YAML 문법 오류가
있어 Stack 명령 실행 전에 수정이 필요합니다. 또한 `test/Spec.hs`의
`Given Lib / when use appRunner function / should be succeeded` 테스트는 종료되지 않는
서버를 직접 실행하므로, 테스트가 종료되도록 수정해야 마지막 서버 실행 단계로 진행됩니다.

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
