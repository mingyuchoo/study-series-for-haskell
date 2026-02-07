# demo-haskell

Haskell Yesod 웹 프레임워크 기반 블로그 애플리케이션입니다.

## 기술 스택

- **언어**: Haskell (GHC 9.12.2)
- **웹 프레임워크**: Yesod
- **템플릿**: Shakespeare (Hamlet, Cassius, Julius)
- **ORM**: Persistent + SQLite3
- **빌드**: Cabal 3.16

## 주요 기능

- **사용자 인증**: 회원가입, 로그인, 로그아웃 (bcrypt 해싱)
- **포스트 CRUD**: 목록 조회, 작성, 상세 보기, 수정, 삭제
- **댓글 CRUD**: 포스트별 댓글 작성 및 삭제
- **REST API**: 포스트/댓글에 대한 JSON API 제공

## 프로젝트 구조

```
src/
├── Foundation.hs        # App 타입 및 Yesod 인스턴스
├── Import.hs            # 공통 import 모듈
├── Model.hs             # Persistent Entity 정의
├── Settings.hs          # 설정
├── Application.hs       # 앱 초기화 및 실행
├── Handler/
│   ├── Home.hs          # 홈 페이지
│   ├── Auth.hs          # 회원가입/로그인/로그아웃
│   ├── Post.hs          # 포스트 HTML 핸들러
│   ├── ApiPost.hs       # 포스트 API 핸들러
│   ├── Comment.hs       # 댓글 HTML 핸들러
│   └── ApiComment.hs    # 댓글 API 핸들러
└── Service/
    ├── AuthService.hs   # 인증 비즈니스 로직
    ├── PostService.hs   # 포스트 비즈니스 로직
    └── CommentService.hs # 댓글 비즈니스 로직
config/
├── models.persistentmodels  # DB 스키마
└── routes.yesodroutes       # 라우트 정의
docs/
├── requirements.md          # 요구사항 관리 문서
└── test-scenarios.md        # E2E 테스트 시나리오
templates/                   # Hamlet 템플릿
├── default-layout.hamlet
├── home.hamlet
├── auth/
│   ├── register.hamlet
│   └── login.hamlet
└── post/
    ├── list.hamlet
    ├── detail.hamlet
    └── form.hamlet
test/
├── Spec.hs              # 테스트 진입점
├── TestFoundation.hs    # 테스트용 App 생성 및 헬퍼
├── Unit/
│   ├── AuthServiceSpec.hs      # 비밀번호 해싱/검증 단위 테스트
│   ├── ApiPostHelperSpec.hs    # 포스트 API 헬퍼 함수 단위 테스트
│   └── ApiCommentHelperSpec.hs # 댓글 API 헬퍼 함수 단위 테스트
└── Integration/
    ├── PostServiceSpec.hs      # 포스트 DB CRUD 통합 테스트
    ├── CommentServiceSpec.hs   # 댓글 DB CRUD 통합 테스트
    └── ApiHandlerSpec.hs       # API 엔드포인트 HTTP 통합 테스트
```

## 빌드 및 실행

```bash
# 빌드
cabal build

# 실행
cabal run demo-haskell
```

서버가 시작되면 http://localhost:3000 에서 접속할 수 있습니다.

## 테스트

```bash
# 전체 테스트 실행
cabal test

# 테스트 결과를 상세히 보기
cabal test --test-show-details=streaming
```

### 테스트 구성

테스트는 **단위 테스트**와 **통합 테스트**로 구분됩니다. 통합 테스트는 in-memory SQLite를 사용하여 실제 DB 없이 실행됩니다.

| 구분 | 테스트 모듈 | 검증 대상 |
|------|-------------|-----------|
| 단위 | `Unit.AuthServiceSpec` | 비밀번호 해싱 및 검증 (bcrypt) |
| 단위 | `Unit.ApiPostHelperSpec` | 포스트 JSON 변환, 입력 파싱 |
| 단위 | `Unit.ApiCommentHelperSpec` | 댓글 JSON 변환, 입력 파싱 |
| 통합 | `Integration.PostServiceSpec` | 포스트 DB CRUD 동작 |
| 통합 | `Integration.CommentServiceSpec` | 댓글 DB CRUD 및 권한 검증 |
| 통합 | `Integration.ApiHandlerSpec` | API 엔드포인트 HTTP 요청/응답 |

## 정적 분석

[HLint](https://github.com/ndmitchell/hlint)를 사용하여 코드 스타일과 잠재적 문제를 분석합니다.

```bash
# HLint 설치 (최초 1회)
cabal install hlint

# 전체 소스 분석
hlint src/

# 특정 파일 분석
hlint src/Handler/Auth.hs

# JSON 형식으로 출력
hlint src/ --json

# 자동 수정 가능한 항목 적용
hlint src/ --refactor --refactor-options="--inplace"
```

### 주요 검사 항목

| 카테고리 | 설명 | 예시 |
|----------|------|------|
| Warning | 코드 개선 제안 | `map f (map g xs)` → `map (f . g) xs` |
| Suggestion | 스타일 권장사항 | `if x then True else False` → `x` |
| Error | 잠재적 버그 | 불필요한 import, 미사용 변수 |

## 라우트

### 웹 페이지 (HTML)

| 메서드    | 경로                               | 설명              |
|-----------|------------------------------------|--------------------|
| GET       | `/`                                | 홈 페이지          |
| GET, POST | `/auth/register`                   | 회원가입           |
| GET, POST | `/auth/login`                      | 로그인             |
| POST      | `/auth/logout`                     | 로그아웃           |
| GET       | `/posts`                           | 포스트 목록        |
| GET, POST | `/posts/new`                       | 포스트 작성        |
| GET       | `/posts/detail/:id`                | 포스트 상세        |
| GET, POST | `/posts/edit/:id`                  | 포스트 수정        |
| POST      | `/posts/delete/:id`                | 포스트 삭제        |
| POST      | `/posts/detail/:id/comments`       | 댓글 작성          |
| POST      | `/comments/delete/:id`             | 댓글 삭제          |

### REST API (JSON)

| 메서드 | 경로                        | 설명             |
|--------|-----------------------------|------------------|
| GET    | `/api/posts`                | 포스트 목록 조회 |
| POST   | `/api/posts`                | 포스트 생성      |
| GET    | `/api/posts/:id`            | 포스트 상세 조회 |
| PUT    | `/api/posts/:id`            | 포스트 수정      |
| DELETE | `/api/posts/:id`            | 포스트 삭제      |
| GET    | `/api/posts/:id/comments`   | 댓글 목록 조회   |
| POST   | `/api/posts/:id/comments`   | 댓글 생성        |
| DELETE | `/api/comments/:id`         | 댓글 삭제        |

## 라이선스

MIT
