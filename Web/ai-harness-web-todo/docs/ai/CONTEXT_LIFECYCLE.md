# Context Lifecycle

컨텍스트는 작성으로 끝나지 않고 검색, 검증, 공고화와 폐기를 반복합니다.

```text
User Request
      |
      v
Current Task
      |
      v
docs/ai/INDEX.md
      |
      v
Hierarchical Retrieval
      |
      +--> Architecture
      +--> Domain
      +--> ADR
      +--> Contracts
      +--> Incidents
      |
      v
Impact Analysis
      |
      v
Change Plan
      |
      v
Implementation
      |
      v
Verification
      |
      +--> cabal test all
      +--> architecture-check.sh
      +--> validate-context.sh
      |
      v
Consolidation
      |
      +--> ADR
      +--> Docs
      +--> Tests and Static Rules
      +--> Generated Facts
      |
      v
Long-term Repository Memory
      |
      +----------------------> Next Task
```

## 상태 전이

1. Retrieve: 현재 작업에 필요한 최소 컨텍스트를 계층적으로 찾습니다.
2. Verify: 문서의 설명을 코드, 타입, 테스트와 실행 사실로 확인합니다.
3. Apply: 영향 분석과 위험 수준에 맞게 변경합니다.
4. Consolidate: 미래에도 유효한 학습만 적절한 Canonical Source로 승격합니다.
5. Collect: 오래되거나 중복되거나 충돌하는 정보를 수정하거나 폐기합니다.

## 이 저장소에서 수명 주기가 실제로 도는 예

`INC-2026-001`이 한 바퀴를 모두 보여줍니다.

1. 사고가 발생하고 사실을 `docs/incidents/INC-2026-001.md`에 기록합니다.
2. 조치가 `Todo.Store.Migration.configureConnection`의 코드가 됩니다.
3. 재발 방지가 `RegressionSpec`의 실행 가능한 테스트가 됩니다.
4. 반복 가능한 부분만 `lessons.md`의 `LESSON-001`, `LESSON-002`로 승격합니다.
5. 연결 설정이라는 운영 결정이 `src/store/docs/architecture.md`에 남습니다.

사고 문서 하나에 모든 것을 적어두는 것이 아니라, 각 조각이 어긋나면 실패하는 자리로 옮겨 간다는 점이 핵심입니다.

모델의 대화 기록은 이 수명 주기의 영구 저장소가 아닙니다. 저장소가 장기 기억이며 AI 도구는 이를 읽고 판단하는 교체 가능한 인지 엔진입니다.
