# scotty-t00-init

Scotty 웹 프레임워크를 사용한 Haskell 웹 서버 초기 프로젝트입니다. 포트 4000에서 "Hello, World!"를 응답하는 간단한 예제입니다.

## 프로젝트 구조

```
.
├── app/Main.hs          # 애플리케이션 진입점
├── src/Lib.hs           # Scotty 웹 서버 (포트 4000)
├── test/Spec.hs         # 테스트 스위트
├── package.yaml         # 프로젝트 설정 및 의존성
├── stack.yaml           # Stack 빌드 설정 (LTS 24.20)
├── Makefile             # 빌드/실행/Docker 명령어
└── docker/              # Docker 관련 파일
```

## 의존성

- `base`
- `containers`
- `flow`
- `parallel`
- `scotty`

## 빌드 및 실행

```bash
# 전체 빌드 및 실행
make all

# 빌드만
make build

# 실행만
make run

# 테스트
make test

# 파일 변경 감시 테스트
make watch-test
```

## Docker

```bash
# Docker 이미지 빌드 및 실행
make docker-run

# Docker Compose 사용
make docker-compose-up
make docker-compose-down
```

## 사용법

서버 실행 후 브라우저에서 `http://localhost:4000` 으로 접속하면 "Hello, World!" 페이지를 확인할 수 있습니다.
