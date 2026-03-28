# warp-t00-init

Warp 웹 서버의 기본 사용법을 학습하기 위한 프로젝트입니다. WAI(Web Application Interface)와 Warp를 사용하여 간단한 HTTP 서버를 구현합니다.

## 주요 기능

- **app1** - 단순 텍스트 응답 (`"Hello, World!"`)
- **app2** - HTML 파일(`index.html`) 응답
- **app3** - 경로 기반 라우팅 (`/`, `/raw/`, 404 처리)

기본 포트: `4000`

## 기술 스택

- **GHC**: 9.6.x (LTS 24.20)
- **빌드 도구**: Stack
- **테스트 프레임워크**: Hspec

## 의존성 패키지

| 패키지 | 설명 |
| --- | --- |
| `warp` | 고성능 HTTP 서버 |
| `wai` | Web Application Interface |
| `http-types` | HTTP 상태 코드 및 헤더 타입 |
| `flow` | 함수 파이프라인 연산자 (`<\|`) |
| `containers` | 표준 컨테이너 자료구조 |
| `parallel` | 병렬 평가 전략 |

## 프로젝트 구조

```
.
├── app/Main.hs          # 실행 진입점
├── src/Lib.hs           # Warp 서버 및 라우팅 로직
├── test/Spec.hs         # 테스트 스펙
├── index.html           # 정적 HTML 파일
├── package.yaml         # 패키지 설정
├── stack.yaml           # Stack 설정 (LTS 24.20)
├── docker/Dockerfile    # Docker 빌드 파일
└── Makefile             # 빌드 자동화
```

## 빌드 및 실행

```bash
# 의존성 설치 및 빌드
make setup
make build

# 실행
make run

# 테스트
make test

# 파일 변경 감지 테스트
make watch-test
```

## Docker

```bash
# Docker 이미지 빌드 및 실행
make docker-build
make docker-run

# Docker Compose
make docker-compose-up
make docker-compose-down
make docker-compose-logs
```

## 참고 자료

- <https://crypto.stanford.edu/~blynn/haskell/warp.html>
- <https://stackoverflow.com/questions/22620294/minimal-warp-webserver-example>
- <https://wiki.haskell.org/Web/Servers#Warp>
