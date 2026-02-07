---
name: new-handler
description: Yesod Handler 스캐폴딩. "핸들러 생성", "Handler 추가", "라우트 핸들러 만들어", "새 API 엔드포인트", "새 페이지 추가" 등의 요청 시 자동 트리거됩니다.
allowed-tools: Read, Edit, Write, Grep, Glob, AskUserQuestion
---

# Yesod Handler 스캐폴딩

이 스킬은 CLAUDE.md의 "Handler 작성 패턴"과 "컨벤션 준수" 원칙에 따라 새로운 Yesod Handler를 생성합니다.

## 트리거 조건

다음 요청 시 이 스킬을 사용합니다:

- "새 핸들러 만들어", "Handler 추가해줘"
- "API 엔드포인트 추가", "새 페이지 만들어"
- "GET/POST/PUT/DELETE 라우트 추가"
- 특정 엔티티에 대한 CRUD 핸들러 요청

## 실행 순서

### 1단계: 요구사항 확인

- 사용자의 요청에 REQ-ID가 있는지 확인합니다.
- **없으면 반드시 `/req register` 로직을 먼저 수행하여 REQ-ID를 부여합니다.**
- REQ-ID 없이 코드 생성을 진행하지 않습니다.

### 2단계: 기존 패턴 파악

반드시 기존 Handler 파일들을 먼저 읽어 패턴을 파악합니다:

```
1. Glob으로 src/Handler/*.hs 파일 목록 확인
2. 가장 최근 수정된 Handler 파일 1개를 Read로 읽기
3. 확인할 패턴:
   - 언어 확장 (LANGUAGE pragmas)
   - import 구조
   - 함수 시그니처 스타일
   - runDB 사용 패턴
   - 응답 형식 (Html vs Value)
   - 에러 처리 패턴
```

### 3단계: 사용자 입력 수집

AskUserQuestion으로 필요한 정보를 수집합니다:

- **핸들러 이름**: PascalCase (예: `Product`, `Category`)
- **HTTP 메서드**: GET, POST, PUT, DELETE 중 선택
- **응답 타입**: HTML 페이지 / JSON API 중 선택
- **관련 엔티티**: Persistent 엔티티 이름 (선택사항)

### 4단계: 라우트 등록

`config/routes.yesodroutes` 파일에 라우트를 추가합니다:

```
-- 예시 패턴
/entity EntityListR GET POST
/entity/#EntityId EntityDetailR GET PUT DELETE
```

### 5단계: Handler 파일 생성

`src/Handler/{Name}.hs` 파일을 생성합니다. 반드시 아래 구조를 따릅니다:

```haskell
-- src/Handler/{Name}.hs
module Handler.{Name} where

import Import

-- [REQ-XXXX] {설명}
get{Name}ListR :: Handler Html  -- 또는 Handler Value
get{Name}ListR = do
    -- TODO: 비즈니스 로직 구현
    undefined
```

### 6단계: 사용자 코드 요청

핸들러의 핵심 비즈니스 로직 부분은 사용자에게 작성을 요청합니다:

- DB 쿼리 로직 (어떤 조건으로 조회/필터링할지)
- 응답 데이터 구조 (어떤 필드를 포함할지)
- 에러 처리 전략 (404, 400 등 어떤 경우에 에러를 반환할지)

### 7단계: 통합 확인

- `config/routes.yesodroutes`에 라우트가 정상 등록되었는지 확인
- `src/Application.hs` 또는 `src/Foundation.hs`에서 Handler 모듈 import가 필요한지 확인
- `requirements.md`의 영향 파일 목록에 생성/수정된 파일을 추가

## 필수 규칙

- top-level 함수에는 반드시 타입 시그니처를 명시합니다
- `String` 대신 `Text`를 사용합니다
- Partial 함수(`head`, `tail`, `!!`)를 사용하지 않습니다
- 주석에 `-- [REQ-XXXX]` 형태로 요구사항 ID를 표기합니다
- 한 번에 하나의 Handler 파일만 생성합니다
