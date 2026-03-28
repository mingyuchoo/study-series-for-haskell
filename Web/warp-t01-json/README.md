# warp-t01-json

Warp 웹 서버를 사용한 JSON 응답 예제 프로젝트입니다.

## 개요

- Haskell의 `warp` 라이브러리를 사용하여 간단한 웹 서버를 구현합니다.
- GET, POST, PUT, DELETE HTTP 메서드를 처리합니다.
- 쿼리 파라미터를 JSON으로 응답하는 기능을 포함합니다.
- 정적 HTML 파일(`www/index.html`)을 서빙합니다.

## 기술 스택

| 항목 | 내용 |
|------|------|
| 언어 | Haskell (GHC2024) |
| 빌드 도구 | Stack |
| 웹 서버 | Warp |
| 주요 라이브러리 | warp, wai, aeson, http-types, flow |
| 포트 | 4000 |

## 프로젝트 구조

```
.
├── app/Main.hs          # 엔트리 포인트
├── src/Lib.hs           # 웹 서버 및 라우팅 로직
├── test/Spec.hs         # 테스트
├── www/index.html       # 정적 HTML 페이지
├── docker/              # Docker 관련 파일
├── package.yaml         # 패키지 설정
├── stack.yaml           # Stack 설정
└── Makefile             # 빌드/실행 자동화
```

## 프로젝트 생성 방법

```bash
stack new <project-name> mingyuchoo/new-template
```

## 빌드

```bash
# 기본 빌드
make build

# 또는 직접 실행
stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"
```

## 테스트

```bash
# 테스트 실행
make test

# Watch 모드
make watch-test

# 커버리지 포함
make watch-coverage

# ghcid 사용
make ghcid
```

## 실행

```bash
make run

# 또는 직접 실행
stack run
```

서버가 `http://localhost:4000`에서 시작됩니다.

## API 엔드포인트

### GET `/`

정적 HTML 페이지(`www/index.html`)를 반환합니다.

```bash
curl http://localhost:4000/
```

### GET `/expr?q=<value>`

쿼리 파라미터 `q`의 값을 JSON(`application/json`)으로 반환합니다.

```bash
curl http://localhost:4000/expr?q=HelloWorld!
```

### POST `/`

```bash
curl -X POST http://localhost:4000/
```

### PUT `/`

```bash
curl -X PUT http://localhost:4000/
```

### DELETE `/`

```bash
curl -X DELETE http://localhost:4000/
```

## Docker

```bash
# Docker 이미지 빌드
make docker-build

# Docker 컨테이너 실행 (포트 8000)
make docker-run

# Docker Compose 사용
make docker-compose-up
make docker-compose-down
make docker-compose-logs
```

## 참고 자료

- <https://aosabook.org/en/posa/warp.html>
- <https://crypto.stanford.edu/~blynn/haskell/warp.html>
- <https://stackoverflow.com/questions/22620294/minimal-warp-webserver-example>
- <https://wiki.haskell.org/Web/Servers#Warp>
