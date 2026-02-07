---
name: impact-analysis
description: 변경 영향 분석. "영향 분석", "영향 범위 파악", "어디 수정해야 해", "변경 시 영향", "이거 바꾸면 어디 영향" 등의 요청 시 자동 트리거됩니다. 코드 변경 전 반드시 수행합니다.
allowed-tools: Read, Grep, Glob, AskUserQuestion
---

# 변경 영향 분석

이 스킬은 CLAUDE.md의 "영향 범위 파악" 원칙에 따라, 코드 변경 전 영향받는 파일과 모듈을 분석합니다.

## 트리거 조건

다음 상황에서 이 스킬을 사용합니다:

- 사용자가 코드 변경을 요청했을 때 (자동 트리거)
- "영향 분석해줘", "어디 수정해야 해?" 요청 시
- "이 함수 바꾸면 어디 영향이야?" 요청 시
- 스펙 변경이 발생했을 때

## 분석 순서

### 1단계: 변경 대상 식별

사용자 요청에서 변경 대상을 파악합니다:

- 변경할 엔티티/모듈/함수 이름
- 변경의 성격 (필드 추가, 타입 변경, 함수 시그니처 변경, 로직 변경 등)

### 2단계: 레이어별 영향 추적

Haskell/Yesod의 Handler → Service → Model 레이어 구조를 따라 분석합니다:

#### Model 레이어 변경 시 (config/models.persistentmodels, src/Model.hs)

```
1. Grep으로 해당 엔티티명을 참조하는 모든 파일 검색
   - 패턴: "{EntityName}", "{EntityName}Id", "{entityName}Field"
2. Service 레이어에서의 사용처 확인
   - src/Service/*.hs 에서 해당 엔티티 import/사용 확인
3. Handler 레이어에서의 사용처 확인
   - src/Handler/*.hs 에서 해당 엔티티 import/사용 확인
4. Template에서의 사용처 확인
   - templates/**/*.hamlet 에서 해당 엔티티 필드 참조 확인
5. Route 정의 확인
   - config/routes.yesodroutes 에서 관련 라우트 확인
```

#### Service 레이어 변경 시 (src/Service/*.hs)

```
1. 변경할 함수의 타입 시그니처 확인
2. Grep으로 해당 함수를 호출하는 Handler 파일 검색
3. 해당 함수가 사용하는 Model 엔티티 확인
4. 동일 Service 모듈 내 다른 함수의 의존성 확인
```

#### Handler 레이어 변경 시 (src/Handler/*.hs)

```
1. 관련 Route 정의 확인 (config/routes.yesodroutes)
2. 사용하는 Service 함수 확인
3. 사용하는 Template 파일 확인 (templates/**/*.hamlet)
4. Foundation.hs 에서의 라우트 등록 확인
```

### 3단계: 영향 보고서 출력

다음 형식으로 영향 분석 결과를 출력합니다:

```markdown
## 영향 분석 결과

### 변경 대상
- 파일: {대상 파일}
- 변경 내용: {변경 설명}

### 직접 영향 (반드시 수정 필요)
| 파일 | 영향 내용 | 우선순위 |
|------|-----------|---------|
| ... | ... | 높음/중간/낮음 |

### 간접 영향 (확인 필요)
| 파일 | 확인 사항 |
|------|-----------|
| ... | ... |

### 영향 없음 확인 완료
- {확인한 파일 목록}
```

### 4단계: requirements.md 갱신

분석 결과의 영향 파일 목록을 `requirements.md`의 해당 요구사항에 갱신합니다.

## 분석 팁

- Haskell의 타입 시스템 덕분에, 타입 시그니처 변경은 컴파일 에러로 정확히 추적됩니다
- `import` 문을 통해 모듈 간 의존성을 명확히 파악할 수 있습니다
- Template 파일(.hamlet)에서의 변수 참조도 반드시 확인합니다
- `cabal build` 결과로 타입 에러가 발생하는 파일을 추가 확인할 수 있습니다
