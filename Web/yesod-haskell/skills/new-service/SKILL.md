---
name: new-service
description: Service 레이어 모듈 스캐폴딩. "서비스 생성", "비즈니스 로직 모듈 추가", "Service 만들어", "서비스 레이어 추가" 등의 요청 시 자동 트리거됩니다.
allowed-tools: Read, Edit, Write, Grep, Glob, AskUserQuestion
---

# Service 레이어 스캐폴딩

이 스킬은 CLAUDE.md의 "Service 레이어 패턴"에 따라 비즈니스 로직 모듈을 생성합니다.

## 트리거 조건

다음 요청 시 이 스킬을 사용합니다:

- "서비스 모듈 만들어", "Service 추가해줘"
- "비즈니스 로직 분리해줘"
- 특정 도메인의 서비스 레이어 생성 요청

## 실행 순서

### 1단계: 요구사항 확인

- REQ-ID가 없으면 `requirements.md`에 먼저 등록합니다.
- REQ-ID 없이 코드 생성을 진행하지 않습니다.

### 2단계: 기존 패턴 파악

기존 Service 파일을 반드시 먼저 읽습니다:

```
1. Glob으로 src/Service/*.hs 파일 목록 확인
2. 기존 Service 파일 1개를 Read로 읽기
3. 확인할 패턴:
   - import 구조
   - 함수 시그니처 (ReaderT SqlBackend Handler vs Handler)
   - 트랜잭션 처리 방식
   - 에러 처리 패턴 (Either, Maybe, 커스텀 타입)
```

### 3단계: 사용자 입력 수집

AskUserQuestion으로 핵심 설계 결정 사항을 확인합니다:

- **서비스 이름**: PascalCase (예: `OrderService`, `UserService`)
- **관련 엔티티**: 어떤 Persistent 엔티티를 다루는지
- **주요 함수 목록**: 어떤 비즈니스 함수가 필요한지

### 4단계: Service 파일 생성

`src/Service/{Name}Service.hs` 파일을 생성합니다:

```haskell
-- src/Service/{Name}Service.hs
module Service.{Name}Service where

import Import
import Database.Persist.Sql (SqlBackend)

-- [REQ-XXXX] {서비스 설명}

-- | {함수 설명}
{functionName} :: {InputType} -> ReaderT SqlBackend Handler {OutputType}
{functionName} input = do
    -- TODO: 비즈니스 로직 구현
    undefined
```

### 5단계: 사용자 코드 요청

비즈니스 로직의 핵심 판단 부분은 사용자에게 구현을 요청합니다:

- 비즈니스 규칙 (예: 주문 금액 최소값, 재고 확인 로직)
- 유효성 검증 규칙
- 에러 타입과 에러 처리 전략

### 6단계: 통합 확인

- Handler에서 Service 함수를 호출하는 패턴을 안내합니다
- `requirements.md`의 영향 파일 목록 갱신

## 필수 규칙

- 순수 함수를 우선 고려합니다. DB 접근이 필요한 경우에만 `ReaderT SqlBackend Handler` 사용
- `String` 대신 `Text` 사용
- 타입 시그니처 필수
- `-- [REQ-XXXX]` 주석 필수
- 에러 처리는 `Either`, `Maybe`, 또는 커스텀 에러 타입 사용
