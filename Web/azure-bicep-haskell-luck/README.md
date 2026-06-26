# 운을 부르는 실천 체크리스트 — 웹 서비스

행운 연구(리처드 와이즈먼)와 공간·습관 정비를 매일 기록하는 체크리스트 서비스.
회원가입, 로그인/로그아웃, 프로필 설정, 일별 기록 달력 보기를 제공한다.

## 기술 스택

- 데이터베이스: PostgreSQL 16
- 백엔드: Haskell + Servant (JWT 인증, postgresql-simple, bcrypt)
- 프런트엔드: TypeScript + Solid.js + Vite
- 구조: npm workspaces 모노레포

## 디렉터리 구조

```
azure-bicep-haskell-luck/
├── package.json            # 워크스페이스 루트 (frontend 워크스페이스 + 스크립트)
├── docker-compose.yml      # PostgreSQL 개발 컨테이너
├── .env.example            # 백엔드 환경변수 예시
├── backend/                # Haskell / Servant API
│   ├── luck-backend.cabal
│   ├── app/Main.hs         # 부트스트랩 (설정, 풀, JWT, CORS, Warp)
│   ├── src/Luck/
│   │   ├── Config.hs       # 환경변수 로딩
│   │   ├── Types.hs        # DTO, 요청/응답, JWT 페이로드, 카탈로그
│   │   ├── Database.hs     # 커넥션 풀 + SQL 쿼리
│   │   ├── Auth.hs         # 비밀번호 해시 + JWT 발급
│   │   ├── Api.hs          # Servant API 타입
│   │   ├── Server.hs       # 핸들러 구현
│   │   └── App.hs          # 앱 환경 + 핸들러 모나드
│   └── migrations/0001_init.sql
└── frontend/               # Solid.js SPA
    ├── index.html
    ├── vite.config.ts      # /api → 백엔드(8080) 프록시
    └── src/
        ├── App.tsx         # 라우팅 + 보호 레이아웃
        ├── lib/            # api 클라이언트, 인증 스토어, 날짜 유틸
        ├── components/     # Medallion, Checklist, Layout
        ├── pages/          # Login, Signup, Profile, Dashboard, Calendar
        └── styles.css      # 야간 하늘 디자인 시스템
```

## 빠른 시작

사전 요구사항: Docker, GHC + cabal (GHC 9.6 이상 권장), Node.js 18 이상.

### 1) 데이터베이스 기동

```bash
cp .env.example .env          # 필요 시 값 수정
docker compose up -d db
```

`migrations/0001_init.sql` 이 컨테이너 최초 기동 시 자동 적용된다.
백엔드도 기동 시 스키마를 멱등적으로 한 번 더 보장한다.

### 2) 백엔드 실행

```bash
cd backend
cabal build                   # 최초 1회 의존성 빌드 (시간이 걸린다)
DATABASE_URL=postgresql://luck:luck@localhost:5432/luck \
JWT_SECRET=dev-secret-change-me \
PORT=8080 \
cabal run luck-backend
```

API가 `http://localhost:8080` 에서 동작한다.

### 3) 프런트엔드 실행

```bash
npm install                   # 루트에서 (워크스페이스 일괄 설치)
npm run dev:frontend          # http://localhost:3000
```

개발 서버는 `/api` 요청을 백엔드(8080)로 프록시하므로 CORS 설정 없이 동작한다.

## 데이터 모델

- `users` — id(uuid), email(unique), password_hash, display_name, bio, timezone, created_at
- `daily_records` — user_id, record_date, completed(jsonb: 완료 항목 key 배열), note, updated_at
  - 기본키 `(user_id, record_date)`

일별 항목(카탈로그)은 백엔드 `Luck.Types.catalog` 가 정본이며 `GET /api/catalog` 로 제공된다.
달력은 각 날짜의 `completed / total` 비율로 칸 색을 5단계(0~4)로 칠한다.

## API 레퍼런스

공개 라우트:

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| POST | `/api/auth/signup` | 회원가입 `{ email, password, displayName }` → `{ token, user }` |
| POST | `/api/auth/login` | 로그인 `{ email, password }` → `{ token, user }` |
| POST | `/api/auth/logout` | 로그아웃 (JWT는 무상태이므로 클라이언트가 토큰 폐기) |
| GET | `/api/catalog` | 일별 항목 목록 |

보호 라우트 (헤더 `Authorization: Bearer <token>` 필요):

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| GET | `/api/me` | 내 프로필 |
| PUT | `/api/me` | 프로필 수정 `{ displayName, bio, timezone }` |
| GET | `/api/records?from=YYYY-MM-DD&to=YYYY-MM-DD` | 기간 내 기록(달력용) |
| GET | `/api/records/:date` | 특정 날짜 기록 |
| PUT | `/api/records/:date` | 기록 저장 `{ completed: string[], note }` |

## 인증 방식

- 비밀번호는 bcrypt로 해싱해 저장한다.
- 로그인/가입 시 7일 만료 JWT를 발급한다. 서명 키는 `JWT_SECRET` 에서 파생되므로
  서버를 재시작해도 발급된 토큰이 유효하다.
- 프런트엔드는 토큰을 `localStorage` 에 저장하고 모든 요청에 Bearer로 첨부한다.
  401 응답을 받으면 토큰을 비우고 로그인 화면으로 보낸다.

## 보안 / 운영 배포 체크리스트

애플리케이션 레벨 하드닝은 코드에 반영되어 있고, 아래는 **배포 시 반드시 설정/확인**해야 하는 항목이다.

**필수 환경변수 (운영)**

- `APP_ENV=production` — 이 값이면 아래 필수값이 없을 때 서버가 기동을 거부한다(fail-fast).
- `JWT_SECRET` — 길고 무작위한 값. 생성 예: `openssl rand -base64 48`. (미설정 시 운영 기동 거부)
- `DATABASE_URL` — 관리형 시크릿으로 주입 (기본 `luck:luck` 자격증명 사용 금지).
- `ALLOWED_ORIGINS` — 프런트 오리진 화이트리스트(콤마 구분). 비우면 모든 오리진을 허용하므로 운영에선 반드시 지정.
- `ADMIN_EMAILS` — 관리자 이메일(콤마 구분). 지정하면 "첫 가입자=관리자" 규칙이 비활성화되어 권한 탈취 레이스를 막는다. 기동 시 해당 계정을 자동 관리자로 승격한다.

**코드에 반영된 하드닝**

- JWT 서명 키는 시크릿을 SHA-256 으로 파생(길이 무관하게 안전), 운영에서 시크릿 미설정 시 기동 거부.
- 보안 응답 헤더: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, API용 `Content-Security-Policy: default-src 'none'`, 운영 모드에선 `Strict-Transport-Security`(HSTS).
- CORS 오리진 화이트리스트(`ALLOWED_ORIGINS`).
- 인증 엔드포인트(`/api/auth/*`) IP 기준 rate limiting(기본 60초당 10회, `X-Forwarded-For` 우선).
- 관리자 권한은 매 요청 DB에서 확인(권한 회수 즉시 반영), 모든 쿼리는 파라미터 바인딩(SQL 인젝션 차단), 비밀번호는 bcrypt.

**배포 인프라에서 처리해야 할 항목**

- **TLS 종단 + HTTP→HTTPS 리다이렉트**: 인그레스(Azure Front Door/App Gateway 등)에서 강제. 앱은 HSTS 헤더만 보낸다(평문 HTTP로는 토큰이 노출되므로 TLS 필수).
- **SPA 문서 CSP/보안 헤더**: 프런트 정적 호스트에서 `Content-Security-Policy` 등을 설정한다(이 백엔드는 JSON API만 제공하므로 SPA 문서 헤더를 제어하지 않는다).
- (권장) **토큰 저장 방식**: 현재 프런트는 토큰을 `localStorage` 에 저장한다(XSS 시 탈취 위험). 더 강한 보안이 필요하면 `httpOnly`+`Secure`+`SameSite` 쿠키 인증으로 전환을 검토한다 — auth 흐름과 CSRF 대책이 함께 바뀌는 별도 작업이다.

## 다음 단계

- 이 저장소는 코드베이스 자체가 산출물이다. 백엔드는 `cabal build`,
  프런트엔드는 `npm install` 을 처음 한 번 실행해야 한다. 환경에 따라
  cabal 의존성 버전 경계를 조정해야 할 수 있다.
- 확장 아이디어: 주간/공간 항목의 별도 기록, 연속 달성(스트릭) 집계 API,
  테스트(hspec/QuickCheck), 백엔드 Docker 이미지화.
