# CLAUDE.md — AI 코드 생성 변경 관리 가이드

## 프로젝트 개요

이 프로젝트는 AI 코드 생성 도구의 비결정성 문제를 방지하고, 스펙↔코드 간 형상 일관성을 유지하기 위한 규칙을 따릅니다.

---

## 핵심 원칙

### 1. 절대 재생성 금지 (No Regeneration)

- 이미 존재하는 코드를 **전체 재생성하지 마세요.**
- 스펙이 변경되면 기존 코드 위에서 **해당 부분만 증분 수정(incremental edit)**하세요.
- 파일을 새로 작성하는 것이 아니라, 기존 파일을 읽고 변경이 필요한 부분만 수정합니다.

### 2. 컨벤션 준수 (Convention First)

- 새 코드를 생성할 때는 반드시 기존 코드의 패턴을 따르세요.
- 동일 디렉토리 내 기존 파일을 먼저 확인하고, 그 구조·네이밍·패턴을 그대로 적용하세요.
- 아래 "코드 컨벤션" 섹션의 규칙을 우선 적용합니다.

### 3. 변경 추적성 (Traceability)

- **모든 작업은 `docs/requirements.md`에 등록된 요구사항 ID 기반으로 수행합니다.**
- 사용자의 지시가 요구사항 ID 없이 들어오면, AI가 먼저 `docs/requirements.md`에 요구사항을 등록한 뒤 작업을 시작합니다.
- 커밋 메시지 형식: `[REQ-XXXX] 변경 내용 요약`
- 코드 내 주요 변경 지점에 주석을 남기세요:

  ```
  // [REQ-XXXX] 요구사항 변경에 따른 수정 (2025-XX-XX)
  ```

#### 요구사항 등록 → 작업 수행 흐름

```
사용자 지시 입력
    │
    ▼
┌─────────────────────────────────┐
│ 1. 요구사항 ID가 명시되어 있는가?│
└─────────┬───────────┬───────────┘
          │ Yes       │ No
          ▼           ▼
    ID 확인 후    requirements.md에
    작업 진행     신규 등록 (ID 자동 부여)
          │           │
          ▼           ▼
┌─────────────────────────────────┐
│ 2. requirements.md 상태 갱신    │
│    (등록 → 분석완료 → 진행중)   │
└─────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ 3. 영향 범위 파악               │
│    - 변경 대상 파일 목록 확인   │
│    - requirements.md 영향 파일 갱신│
└─────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ 4. 증분 수정 수행               │
│    - 코드 주석에 REQ-XXXX 명시  │
│    - 한 번에 1개 파일/클래스 단위│
└─────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────┐
│ 5. 작업 완료 후                 │
│    - requirements.md 상태 → 완료│
│    - 커밋 메시지에 REQ-XXXX 포함│
└─────────────────────────────────┘
```

### 4. 생성 범위 최소화 (Small Scope)

- 한 번에 하나의 함수 또는 하나의 클래스만 생성/수정하세요.
- 전체 모듈을 한 번에 만들지 마세요.
- 생성 후 반드시 기존 코드와의 일관성을 확인하세요.

---

## 코드 컨벤션

> **아래 항목을 프로젝트에 맞게 수정하세요.**

### 언어 및 프레임워크

- 런타임 환경: Haskell GHC 9.12.2
- 언어: Haskell 2024
- 프레임워크: Yesod Web Framework
- 웹 화면 템플릿: Shakespeare (Hamlet, Cassius, Julius)
- 데이터베이스: SQLite3 (Persistent ORM)
- 빌드 도구: Cabal 3.16

### 네이밍 규칙

- 모듈명: PascalCase (예: `Handler.Order`, `Model.User`)
- 타입/데이터 생성자: PascalCase (예: `OrderService`, `UserId`)
- 함수: camelCase (예: `findOrderById`, `getUserName`)
- 상수: camelCase (예: `maxRetryCount`, `defaultTimeout`)
- 파일명: 모듈명과 동일 (예: `Handler/Order.hs`, `Model/User.hs`)
- Persistent Entity: PascalCase (예: `User`, `Order`)
- Route: PascalCase with R suffix (예: `HomeR`, `OrderDetailR`)

### 아키텍처 패턴

- 레이어 구조: Handler → Service → Model (Persistent)
- Handler: HTTP 요청/응답 처리, 라우팅
- Service: 비즈니스 로직 (순수 함수 또는 모나딕 함수)
- Model: Persistent Entity 정의 및 데이터베이스 쿼리
- 타입 안전성: Phantom types, newtype wrappers 활용
- 에러 처리: `Either`, `Maybe`, 커스텀 에러 타입 사용
- 응답 형식: Yesod의 `TypedContent`, JSON 응답은 `returnJson` 사용

### 디렉토리 구조

```
src/
├── Handler/           # 라우트 핸들러 (Controller)
│   ├── Home.hs
│   ├── Order.hs
│   └── User.hs
├── Service/           # 비즈니스 로직
│   ├── OrderService.hs
│   └── UserService.hs
├── Model.hs           # Persistent Entity 정의
├── Foundation.hs      # App 타입 및 인스턴스 정의
├── Import.hs          # 공통 import 모듈
├── Settings.hs        # 설정 (환경변수, 설정 파일)
├── Application.hs     # 앱 초기화 및 실행
└── Utils/             # 공통 유틸리티
    ├── Validation.hs
    └── Response.hs
config/
├── models.persistentmodels  # Persistent 스키마 정의
├── routes.yesodroutes       # 라우트 정의
└── settings.yml             # 설정 파일
templates/             # Shakespeare 템플릿
├── default-layout.hamlet
├── home.hamlet
└── order/
    ├── list.hamlet
    └── detail.hamlet
static/                # 정적 파일 (CSS, JS, 이미지)
test/                  # 테스트 코드
```

---

## 변경 작업 시 워크플로우

### 사용자 지시 수신 시 (최우선 수행)

1. **요구사항 등록 확인**: 사용자의 지시에 REQ-ID가 있는지 확인
2. **ID 없으면 자동 등록**: `docs/requirements.md`에 적절한 구분(F/N/B/R)으로 신규 등록
3. **등록 내용 사용자에게 고지**: "REQ-F002로 등록했습니다. 작업을 진행합니다." 형태로 안내
4. **이후 아래 워크플로우 진행**

### 스펙 변경이 발생했을 때

1. **영향 범위 파악**: 변경되는 스펙이 어떤 파일들에 영향을 주는지 먼저 확인
2. **기존 코드 확인**: 해당 파일들을 읽어서 현재 구현 상태 파악
3. **증분 수정 수행**: 변경이 필요한 부분만 정확히 수정
4. **테스트 코드 동기화**: 변경된 코드에 대응하는 테스트를 함께 수정하거나 추가 (아래 "테스트 필수 규칙" 참조)
5. **테스트 실행 및 검증**: `cabal test`로 전체 테스트 통과 확인
6. **일관성 검증**: 수정 후 관련 파일들과의 일관성 확인
7. **변경 이력 기록**: 커밋 메시지에 스펙 ID 포함, `requirements.md` 상태 갱신

### 신규 기능 개발 시

1. **레퍼런스 확인**: 동일 레이어의 기존 파일을 먼저 확인
2. **패턴 복제**: 기존 파일의 구조를 그대로 따라서 생성
3. **단위별 생성**: 한 번에 하나의 파일/모듈만 생성
4. **타입 시그니처 우선**: 함수 구현 전에 타입 시그니처를 먼저 정의
5. **통합 확인**: 생성 후 호출하는 쪽과 호출받는 쪽의 타입 일치 확인
6. **컴파일 검증**: `cabal build`로 타입 체크
7. **테스트 코드 작성**: 신규 기능에 대한 테스트를 함께 작성 (아래 "테스트 필수 규칙" 참조)
8. **테스트 실행**: `cabal test`로 전체 테스트 통과 확인
9. **요구사항 완료 처리**: `requirements.md` 상태를 `완료`로 갱신

---

## 금지 사항

- ❌ 기존 파일을 삭제하고 새로 작성하는 행위
- ❌ 동일 기능을 완전히 다른 방식으로 재구현하는 행위
- ❌ 프로젝트 컨벤션에 없는 새로운 패턴을 임의로 도입하는 행위
- ❌ 한 번의 작업에서 3개 이상의 파일을 동시에 대규모 변경하는 행위
- ❌ **요구사항 ID 없이 코드를 변경하는 행위 (docs/requirements.md 미등록 상태에서 작업 금지)**
- ❌ 요구사항 상태를 갱신하지 않고 작업을 종료하는 행위
- ❌ 타입 시그니처 없이 함수를 정의하는 행위 (top-level 함수는 반드시 타입 명시)
- ❌ Partial 함수 사용 (`head`, `tail`, `!!` 등) - `Maybe`, `Either` 사용 권장
- ❌ `String` 타입 사용 - `Text` 사용 권장
- ❌ 불필요한 언어 확장(Language Extension) 추가
- ❌ 테스트 코드 없이 신규 기능을 완료 처리하는 행위
- ❌ 기존 테스트를 삭제하거나 비활성화하여 테스트를 통과시키는 행위
- ❌ `cabal test` 실패 상태에서 작업을 완료 처리하는 행위

---

## 역방향 산출물 생성 (리버스 엔지니어링)

감리 또는 고객 산출물 제출이 필요한 경우, 최종 코드를 기반으로 설계서를 재생성할 수 있습니다.

요청 예시:

```
이 코드를 기반으로 상세설계서를 작성해줘.
- 모듈 의존성 다이어그램
- 데이터 타입 정의서
- Handler 라우트 명세
- Persistent Entity 스키마
- 비즈니스 로직 설명
형식은 [프로젝트 산출물 템플릿]을 따라줘.
```

---

## Haskell/Yesod 특화 가이드

### 코드 스타일

- **들여쓰기**: 2칸 또는 4칸 (프로젝트 내 일관성 유지)
- **import 순서**:
  1. Prelude 대체 (예: `import Prelude`)
  2. 외부 라이브러리 (예: `import Data.Text`)
  3. Yesod 관련 (예: `import Yesod`)
  4. 프로젝트 내부 모듈 (예: `import Import`)
- **언어 확장**: 파일 상단에 `{-# LANGUAGE ... #-}` 명시
- **주석**:
  - 모듈 상단: Haddock 주석 (`-- |`)
  - 함수: 타입 시그니처 위에 설명 주석
  - 요구사항 추적: `-- [REQ-XXXX] 설명`

### Persistent 사용 규칙

```haskell
-- config/models.persistentmodels
User
    name Text
    email Text
    createdAt UTCTime default=CURRENT_TIME
    UniqueEmail email
    deriving Show Eq

Order
    userId UserId
    amount Double
    status Text
    createdAt UTCTime default=CURRENT_TIME
    deriving Show Eq
```

- Entity 정의는 `config/models.persistentmodels`에 작성
- 쿼리는 Esqueleto 또는 Persistent DSL 사용
- 트랜잭션은 `runDB` 내에서 처리

### Handler 작성 패턴

```haskell
-- Handler/Order.hs
module Handler.Order where

import Import

-- [REQ-F001] 주문 목록 조회 기능
getOrderListR :: Handler Html
getOrderListR = do
    orders <- runDB $ selectList [] [Desc OrderCreatedAt]
    defaultLayout $ do
        setTitle "주문 목록"
        $(widgetFile "order/list")

-- [REQ-F002] 주문 상세 조회 API
getOrderDetailR :: OrderId -> Handler Value
getOrderDetailR orderId = do
    maybeOrder <- runDB $ get orderId
    case maybeOrder of
        Nothing -> notFound
        Just order -> returnJson order
```

### Service 레이어 패턴

```haskell
-- Service/OrderService.hs
module Service.OrderService where

import Import
import Database.Persist.Sql (SqlBackend)

-- | 주문 생성 비즈니스 로직
-- [REQ-F003] 주문 생성 시 재고 확인
createOrder :: UserId -> Double -> ReaderT SqlBackend Handler OrderId
createOrder userId amount = do
    -- 비즈니스 로직 구현
    now <- liftIO getCurrentTime
    insert $ Order userId amount "pending" now
```

### 테스트 필수 규칙

새로운 기능을 구현하거나 기존 코드를 변경할 때, **반드시 대응하는 테스트 코드를 함께 작성하거나 수정**해야 합니다.

#### 테스트 분류 및 배치

| 테스트 유형 | 대상 | 배치 위치 | 파일 네이밍 |
|-------------|------|-----------|-------------|
| Unit 테스트 | 순수 함수, 비즈니스 로직 (IO 최소) | `test/Unit/` | `<ModuleName>Spec.hs` |
| Integration 테스트 | DB 연동, API 핸들러, 서비스 레이어 | `test/Integration/` | `<ModuleName>Spec.hs` |

#### 테스트 작성 기준

- **Service 레이어 함수를 추가/변경하면** → Unit 또는 Integration 테스트 작성
- **Handler(API)를 추가/변경하면** → Integration 테스트에서 HTTP 요청/응답 검증
- **Model(Entity)을 추가/변경하면** → 관련 Service/Handler 테스트에서 간접 검증
- **순수 함수(비즈니스 로직)를 추가/변경하면** → Unit 테스트 작성
- **버그를 수정하면** → 해당 버그를 재현하는 테스트를 먼저 작성 후 수정

#### 테스트 인프라 패턴

```haskell
-- test/TestFoundation.hs의 헬퍼를 재사용
import TestFoundation (withApp, runTestDB, makeTestApp)

-- Unit 테스트: 순수 함수 검증
spec :: Spec
spec = describe "모듈명" $ do
    it "동작 설명" $ do
        결과 `shouldBe` 기대값

-- Integration 테스트: DB/HTTP 연동 검증
spec :: Spec
spec = withApp $ do
    describe "API 엔드포인트" $ do
        it "동작 설명" $ do
            get SomeRouteR
            statusIs 200
```

#### 테스트 등록

새 테스트 파일을 추가하면 반드시 아래 두 곳에 등록합니다:

1. **`test/Spec.hs`**: `import qualified` 및 `main` 함수에 `spec` 호출 추가
2. **`demo-haskell.cabal`**: `test-suite`의 `other-modules`에 모듈명 추가

#### 테스트 실행

```bash
cabal test              # 전체 테스트 실행
cabal test --test-show-details=direct  # 상세 출력
```

### E2E 테스트 시나리오 문서 자동 생성

사용자 관점의 E2E 테스트 시나리오 문서를 `docs/test-scenarios.md`에 작성합니다. 코드베이스를 분석하여 체계적인 테스트 시나리오를 도출합니다.

#### 시나리오 문서 생성 시점

- **신규 Handler(API) 추가 시** → 해당 엔드포인트의 테스트 시나리오 추가
- **기존 Handler 변경 시** → 영향받는 시나리오 업데이트
- **검증 규칙 추가/변경 시** → 유효성 검사 시나리오 반영
- **예외 처리 추가/변경 시** → 예외 시나리오 반영
- **주요 릴리스 전** → 전체 시나리오 문서 검토 및 갱신

#### 시나리오 필수 포함 항목

| 항목 | 설명 | 예시 |
|------|------|------|
| 시나리오 ID | TC-XXX 형식의 고유 ID | TC-001 |
| 카테고리 | 정상/예외/보안 구분 | 정상 |
| 관련 요구사항 | REQ-XXXX 형식의 추적 ID | REQ-F002 |
| 사전 조건 | 테스트 수행 전 충족 조건 | 사용자 미로그인 상태 |
| 테스트 단계 | Step-by-step 수행 절차 | 1. 회원가입 페이지 접근... |
| 기대 결과 | 각 단계의 예상 결과 | 대시보드로 리다이렉트 |
| 코드 추출 근거 | 소스 파일:라인 번호 | src/Handler/Auth.hs:45-52 |

#### 시나리오 문서 구조

```markdown
# E2E 테스트 시나리오 문서

## 개요
- 문서 버전: X.X
- 최종 갱신일: YYYY-MM-DD
- 커버리지 요약: 엔드포인트 N개 / 시나리오 M개

## 카테고리별 시나리오

### 1. 인증 (Authentication)
#### TC-001: 정상 회원가입
- **카테고리**: 정상
- **관련 요구사항**: REQ-F002
- **사전 조건**: 미로그인 상태, 미등록 이메일
- **테스트 단계**:
  1. GET /auth/register 접근
  2. 유효한 이름/이메일/비밀번호 입력
  3. 가입하기 버튼 클릭
- **기대 결과**: 로그인 페이지로 리다이렉트, 성공 메시지 표시
- **코드 근거**: src/Handler/Auth.hs:23-35

### 2. 포스트 (Post)
...

## 코드-시나리오 추적 매트릭스

| 소스 파일 | 라인 범위 | 관련 시나리오 |
|-----------|-----------|---------------|
| src/Handler/Auth.hs | 23-35 | TC-001, TC-002 |
| src/Handler/Post.hs | 15-28 | TC-010, TC-011 |
...
```

#### 시나리오 도출 체크리스트

코드 분석 시 다음 항목을 반드시 확인하여 시나리오를 도출합니다:

1. **엔드포인트 커버리지**
   - [ ] `config/routes.yesodroutes`의 모든 라우트가 시나리오에 포함되었는가?
   - [ ] 각 HTTP 메서드(GET/POST/PUT/DELETE)별 시나리오가 있는가?

2. **예외 시나리오**
   - [ ] `notFound`, `permissionDenied`, `invalidArgs` 등 에러 응답이 시나리오에 반영되었는가?
   - [ ] 커스텀 에러 메시지가 모두 예외 시나리오로 변환되었는가?

3. **유효성 검사 시나리오**
   - [ ] 폼 검증 규칙(필수 입력, 형식 검사, 길이 제한 등)이 반영되었는가?
   - [ ] `Maybe`, `Either`를 사용한 검증 로직이 시나리오에 포함되었는가?

4. **보안 시나리오**
   - [ ] 인증이 필요한 엔드포인트에 미인증 접근 시나리오가 있는가?
   - [ ] 권한 검증 로직에 대한 비인가 접근 시나리오가 있는가?

#### 변경 추적성 확보

시나리오와 코드 간 **양방향 추적**을 위해 다음 규칙을 준수합니다:

1. **코드 → 시나리오**: 코드 변경 시 영향받는 시나리오 ID를 커밋 메시지에 명시

   ```
   [REQ-F002] 회원가입 이메일 검증 강화 (영향: TC-001, TC-003)
   ```

2. **시나리오 → 코드**: 각 시나리오에 코드 근거(파일:라인) 반드시 명시
   - 코드가 변경되면 해당 시나리오의 코드 근거도 함께 갱신

3. **추적 매트릭스 유지**: 문서 하단에 소스 파일-시나리오 매핑 테이블 유지

---

## 참고: 이 파일의 사용법

이 `CLAUDE.md` 파일을 프로젝트 루트에 위치시키면 Claude Code가 자동으로 읽어서 위 규칙을 따릅니다. `docs/requirements.md`에 요구사항을 관리하여 추적이 가능합니다. 프로젝트 특성에 맞게 "코드 컨벤션" 섹션을 반드시 커스터마이징하세요.
