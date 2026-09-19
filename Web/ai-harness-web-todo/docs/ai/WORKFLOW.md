# AI Work Workflow

## 1. 요청 해석

- 사용자의 표면 요청과 실제 목적을 구분합니다.
- 성공 조건, 제약과 비목표를 확인합니다. 비목표는 `../product/vision.md`에 있습니다.
- 범위가 모호해도 안전하고 되돌릴 수 있는 탐색부터 진행합니다.

## 2. 컨텍스트 검색

- `INDEX.md`에서 관련 경로를 선택합니다.
- 아키텍처, 도메인, ADR, 계약, 사고 기록을 필요한 만큼 읽습니다.
- 현재 코드와 테스트를 검색해 문서의 설명을 검증합니다. 규칙 대부분은 `src/core`에 실행 가능한 형태로 존재합니다.

## 3. 영향 분석과 계획

- `IMPACT_ANALYSIS.md`의 항목을 검토합니다.
- `RISK_LEVELS.md`로 위험을 분류합니다.
- 비사소한 작업은 `../plans/active`에 실행 계획을 작성합니다.
- 기존 패턴 재사용과 가장 작은 일관된 변경을 우선합니다.

## 4. 구현

- 공개 계약과 도메인 불변조건을 유지합니다.
- 규칙은 `core`에 두고 어댑터에 복제하지 않습니다.
- 실패는 예외가 아니라 `Either`로 표현합니다. 예외는 복구할 수 없는 상황에만 씁니다.
- 부분 함수를 쓰지 않습니다. `head`, `fromJust`, 불완전한 패턴 매치를 피합니다.
- 변경을 검증 가능한 단위로 나눕니다.
- 임시 예외에는 책임자, 이유, 제거 조건과 만료 시점을 기록합니다.

## 5. 검증

프로젝트가 지원하는 범위에서 다음을 실행합니다.

```bash
./scripts/quality/lint.sh
```

```bash
./scripts/quality/test.sh
```

```bash
./scripts/quality/architecture-check.sh
```

```bash
./scripts/context/validate-context.sh
```

테스트는 단위, 통합, 계약, 아키텍처, 보안, 회귀 범주를 고려합니다. 각 범주가 실제로 어디서 실행되는지는 `../../tests/README.md`에 있습니다. 실행하지 못한 검증은 이유와 잔여 위험을 명시합니다.

## 6. 공고화

- 계약 변경은 `../contracts`와 호환성 설명에 반영합니다.
- 장기적인 결정은 ADR로 남깁니다.
- 반복 가능한 실패 교훈은 사고 문서와 `../incidents/lessons.md`에 반영합니다.
- 스키마, 라우트, 패키지 의존을 바꿨다면 해당 생성기를 실행합니다.

```bash
./scripts/context/generate-db-schema.sh
```

```bash
./scripts/context/generate-route-map.sh
```

```bash
./scripts/context/generate-api-index.sh
```

```bash
./scripts/context/generate-dependency-map.sh
```

- 완료된 계획은 `../plans/completed`로 이동합니다.

## 7. 완료 판정

`DEFINITION_OF_DONE.md`를 확인하고 코드, 검증, 컨텍스트가 함께 완료된 경우에만 작업을 완료합니다.
