---
name: consistency-check
description: 코드-스펙 일관성 검증. "일관성 확인", "검증해줘", "코드 점검", "컨벤션 체크", "CLAUDE.md 준수 확인" 등의 요청 시 자동 트리거됩니다. 코드 변경 작업 완료 후 자동으로 실행됩니다.
allowed-tools: Read, Grep, Glob, Bash(cabal build:*)
---

# 코드-스펙 일관성 검증

이 스킬은 CLAUDE.md의 모든 규칙 준수 여부를 자동 검증합니다. 코드 변경 후 반드시 실행합니다.

## 트리거 조건

다음 상황에서 이 스킬을 사용합니다:

- 코드 변경 작업 완료 후 (자동 트리거)
- "일관성 확인해줘", "검증해줘" 요청 시
- "컨벤션 위반 확인", "CLAUDE.md 준수 확인" 요청 시

## 검증 항목

### 1. 타입 시그니처 검증

```
검증 방법:
1. Grep으로 src/**/*.hs 에서 top-level 함수 정의 패턴 검색
   - 패턴: "^[a-z][a-zA-Z0-9']* " (함수 정의 시작)
2. 각 함수 정의 바로 위에 타입 시그니처(::)가 있는지 확인
3. 타입 시그니처 없는 top-level 함수를 보고
```

위반 예:

```
❌ src/Handler/Order.hs:15 - getOrderListR 함수에 타입 시그니처 없음
```

### 2. Partial 함수 사용 검증

```
검증 방법:
Grep으로 src/**/*.hs 에서 금지된 Partial 함수 검색:
- 패턴: "\bhead\b", "\btail\b", "\b!!\b"
- import 문의 head/tail은 제외 (모듈명일 수 있음)
```

위반 예:

```
❌ src/Service/OrderService.hs:23 - head 사용 감지. Maybe/패턴 매칭을 사용하세요.
```

### 3. String 타입 사용 검증

```
검증 방법:
Grep으로 src/**/*.hs 에서 String 타입 사용 검색:
- 패턴: ":: .*String" 또는 "-> String"
- 언어 확장이나 외부 라이브러리 타입은 제외
```

위반 예:

```
❌ src/Handler/User.hs:8 - String 타입 사용. Text를 사용하세요.
```

### 4. 요구사항 추적성 검증

```
검증 방법:
1. Read로 requirements.md 읽기
2. 진행중/완료 상태인 REQ-ID 목록 추출
3. Grep으로 src/**/*.hs 에서 각 REQ-ID의 주석 존재 여부 확인
4. 주석 없이 변경된 코드가 있는지 확인
```

위반 예:

```
❌ REQ-F003 - requirements.md에 진행중이나, 코드에 REQ-F003 주석이 없음
```

### 5. 네이밍 규칙 검증

```
검증 방법:
1. 모듈명: Grep으로 "^module " 패턴 검색 → PascalCase 확인
2. 타입/데이터 생성자: Grep으로 "^data |^newtype |^type " 패턴 → PascalCase 확인
3. 함수명: 타입 시그니처에서 → camelCase 확인
4. Route: config/routes.yesodroutes 에서 → PascalCase + R 접미사 확인
```

### 6. import 순서 검증

```
검증 방법:
각 .hs 파일의 import 블록을 읽어 순서 확인:
1. Prelude 대체
2. 외부 라이브러리 (Data.*, Control.*, Database.*)
3. Yesod 관련 (Yesod.*)
4. 프로젝트 내부 모듈 (Import, Handler.*, Service.*, Model.*)
```

### 7. 컴파일 검증

```
검증 방법:
cabal build 실행하여 타입 체크 통과 여부 확인
```

## 검증 결과 출력

```markdown
## 일관성 검증 결과

### 검증 요약
| 항목 | 상태 | 위반 수 |
|------|------|---------|
| 타입 시그니처 | ✅/❌ | N개 |
| Partial 함수 | ✅/❌ | N개 |
| String 타입 | ✅/❌ | N개 |
| 요구사항 추적 | ✅/❌ | N개 |
| 네이밍 규칙 | ✅/❌ | N개 |
| import 순서 | ✅/❌ | N개 |
| 컴파일 | ✅/❌ | - |

### 위반 상세
{위반 항목별 상세 내용}

### 권장 조치
{위반 해결을 위한 구체적 조치 사항}
```

## 주의사항

- 이 스킬은 코드를 읽기만 합니다. 자동 수정하지 않습니다.
- 위반 사항 수정은 사용자의 확인을 받은 후 별도로 진행합니다.
- `cabal build`은 사용자 승인 후 실행합니다.
