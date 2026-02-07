---
name: new-model
description: Persistent Entity 추가. "모델 추가", "엔티티 생성", "테이블 추가", "DB 스키마 추가", "새 데이터 모델" 등의 요청 시 자동 트리거됩니다.
allowed-tools: Read, Edit, Write, Grep, Glob, AskUserQuestion
---

# Persistent Entity 추가

이 스킬은 CLAUDE.md의 "Persistent 사용 규칙"에 따라 새로운 데이터베이스 엔티티를 추가합니다.

## 트리거 조건

다음 요청 시 이 스킬을 사용합니다:

- "새 모델 추가해줘", "엔티티 만들어줘"
- "테이블 추가", "DB 스키마 추가"
- "데이터 모델 정의해줘"

## 실행 순서

### 1단계: 요구사항 확인

- REQ-ID가 없으면 `requirements.md`에 먼저 등록합니다.

### 2단계: 기존 스키마 파악

기존 모델 정의를 반드시 먼저 읽습니다:

```
1. Read로 config/models.persistentmodels 파일 읽기
2. 확인할 패턴:
   - 기존 엔티티 이름 규칙
   - 필드 타입 사용 패턴 (Text, Int, Double, UTCTime 등)
   - Unique 제약 조건 스타일
   - deriving 절 패턴
   - 외래키 참조 방식
3. src/Model.hs 파일도 확인하여 추가 쿼리 함수 패턴 파악
```

### 3단계: 사용자 입력 수집

AskUserQuestion으로 엔티티 설계를 확인합니다:

- **엔티티 이름**: PascalCase (예: `Product`, `Category`)
- **필드 정보**: 사용자에게 필드와 타입을 정의하도록 요청
- **제약 조건**: Unique 제약, 외래키 등
- **인덱스**: 필요한 인덱스 여부

### 4단계: models.persistentmodels에 엔티티 추가

`config/models.persistentmodels` 파일에 엔티티를 **증분 추가**합니다:

```
{EntityName}
    {field1} {Type1}
    {field2} {Type2}
    createdAt UTCTime default=CURRENT_TIME
    Unique{EntityName}{UniqueField} {uniqueField}
    deriving Show Eq
```

### 5단계: 사용자 코드 요청

엔티티의 핵심 설계 결정은 사용자에게 맡깁니다:

- 어떤 필드가 필수/선택인지
- 필드 간 비즈니스 제약 조건 (예: 금액은 0 이상이어야 하는지)
- 어떤 필드에 Unique 제약을 걸지

### 6단계: 통합 확인

- 기존 엔티티와의 외래키 관계가 올바른지 확인
- `requirements.md`의 영향 파일 목록에 `config/models.persistentmodels` 추가

## 필수 규칙

- `String` 대신 `Text` 사용
- 타임스탬프 필드는 `UTCTime` 사용
- 금액 필드는 상황에 따라 적절한 타입 선택 (사용자에게 확인)
- `config/models.persistentmodels` 파일만 수정합니다 (증분 추가)
- 기존 엔티티 정의를 변경하지 않습니다
