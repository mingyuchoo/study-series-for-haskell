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
luck-app/
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

## 주의 / 다음 단계

- 이 저장소는 코드베이스 자체가 산출물이다. 백엔드는 `cabal build`,
  프런트엔드는 `npm install` 을 처음 한 번 실행해야 한다. 환경에 따라
  cabal 의존성 버전 경계를 조정해야 할 수 있다.
- 운영 배포 시에는 `JWT_SECRET` 을 충분히 길고 무작위한 값으로 교체하고,
  HTTPS 와 적절한 CORS 오리진 제한을 적용한다.
- 확장 아이디어: 주간/공간 항목의 별도 기록, 연속 달성(스트릭) 집계 API,
  테스트(hspec/QuickCheck), 백엔드 Docker 이미지화.
