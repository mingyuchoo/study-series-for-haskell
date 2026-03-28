# socket-echo-server

TCP 소켓 기반의 에코 서버입니다. 클라이언트가 보낸 메시지를 그대로 돌려줍니다.

## 프로젝트 구조

```
socket-echo-server/
├── app/Main.hs          -- 엔트리포인트 (stdout 버퍼링 해제 후 서버 실행)
├── src/Lib.hs           -- 소켓 서버 핵심 로직 (포트 8000에서 수신 대기)
├── test/Spec.hs         -- HSpec 기반 테스트
├── package.yaml         -- 프로젝트 메타데이터 및 의존성
├── stack.yaml           -- Stack 리졸버 설정 (lts-24.20)
├── Makefile             -- 빌드/테스트/실행/도커 자동화
└── docker/              -- Docker 관련 파일
```

## 주요 의존성

- `base`
- `network` - TCP 소켓 통신
- `hspec` - 테스트 프레임워크
- `doctest` / `doctest-discover`

## 프로젝트 생성

```bash
stack new <project-name> mingyuchoo/new-template
```

## 빌드

```bash
# 기본 빌드
stack build

# 최적화 빌드
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

## 테스트

```bash
# 단일 실행
stack test --fast

# Watch 모드
stack test --fast --file-watch --watch-all

# 커버리지 포함
stack test --coverage --fast --file-watch --watch-all --haddock

# ghcid 사용
ghcid --command "stack ghci test/Spec.hs"
```

## 실행

```bash
stack run
```

서버가 시작되면 포트 `8000`에서 수신 대기합니다.

## 기능 테스트

```bash
# nc 사용
echo "Hello, Haskell!" | nc localhost 8000
You said: Hello, Haskell!

# telnet 사용
telnet localhost 8000
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Hello, Haskell!
You said: Hello, Haskell!
Connection closed by foreign host
```

## Makefile 명령어

| 명령어 | 설명 |
|---|---|
| `make all` | clean, setup, build, test, run 순차 실행 |
| `make clean` | 빌드 산출물 제거 |
| `make setup` | Stack 설정 및 의존성 설치 |
| `make build` | 최적화 빌드 |
| `make test` | 테스트 실행 |
| `make coverage` | 커버리지 포함 테스트 |
| `make watch-test` | Watch 모드 테스트 |
| `make run` | 서버 실행 |
| `make docker-build` | Docker 이미지 빌드 |
| `make docker-run` | Docker 컨테이너 실행 (포트 8000) |
| `make docker-compose-up` | Docker Compose로 실행 |
| `make docker-compose-down` | Docker Compose 중지 |

## 참고 사항

- 테스트의 `someFunc`는 실제로 포트 `8000`을 바인딩합니다. 동일 포트를 사용하는 프로세스가 있을 경우 `Address already in use` 오류가 발생할 수 있으므로, 테스트 실행 전 서버가 실행 중이지 않은지 확인하세요.
