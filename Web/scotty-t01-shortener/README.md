# scotty-t01-shortener

Scotty 웹 프레임워크를 사용한 간단한 URL 단축기(URL Shortener) 애플리케이션입니다.

## 개요

- 웹 폼을 통해 URL을 등록하면 정수 ID가 부여됩니다.
- `/:id` 경로로 접근하면 등록된 URL로 리다이렉트됩니다.
- URL 목록은 메모리(`IORef`)에 저장되며, 서버 재시작 시 초기화됩니다.
- 서버는 포트 **4000**에서 실행됩니다.

## 기술 스택

| 항목 | 내용 |
|------|------|
| 언어 | Haskell (GHC 9.10.2) |
| 빌드 도구 | Stack (LTS 24.20) |
| 웹 프레임워크 | Scotty |
| HTML 렌더링 | blaze-html |
| 테스트 | doctest-discover |

## 프로젝트 구조

```
├── app/Main.hs          # 엔트리포인트
├── src/Lib.hs           # URL 단축기 핵심 로직 (Scotty 라우트 정의)
├── test/Spec.hs         # 테스트 (doctest-discover)
├── package.yaml         # 패키지 설정
├── stack.yaml           # Stack 설정 (Docker 빌드 지원)
├── Makefile             # 빌드/테스트/실행 자동화
└── docker/Dockerfile    # Docker 이미지 빌드
```

## 빌드 및 실행

```bash
# 전체 빌드 및 실행
make all

# 개별 명령
make setup    # 의존성 설치
make build    # 빌드
make test     # 테스트 실행
make run      # 서버 실행 (http://localhost:4000)
```

## Docker

```bash
# Docker 이미지 빌드 및 실행 (포트 8000)
make docker-run
```

## API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/` | URL 등록 폼 및 목록 표시 |
| POST | `/` | 새 URL 등록 (파라미터: `url`) |
| GET | `/:n` | 등록된 URL로 리다이렉트 (404: 미등록 ID) |

## 참고 자료

- <https://www.stackbuilders.com/tutorials/haskell/getting-started-with-haskell-projects-using-scotty/>

