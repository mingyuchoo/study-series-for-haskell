# Incident Lessons

여러 작업과 패키지에서 반복해서 적용할 수 있는 검증된 교훈만 기록합니다.

| ID | 교훈 | 근거 사고 | 적용 위치 | 검증 방식 |
|---|---|---|---|---|
| LESSON-001 | 여러 프로세스가 같은 SQLite 파일을 쓰는 제품에서는 저널 모드와 busy timeout이 가용성을 결정한다. 기본값에 의존하지 않고 연결마다 명시한다. | INC-2026-001 | `Todo.Store.Migration.configureConnection` | `src/store/tests/Todo/Store/RegressionSpec.hs` |
| LESSON-003 | 경합을 완화하는 설정은 경합하는 작업보다 __먼저__ 적용되어야 한다. 설정 자체가 잠금을 요구하는 경우가 있다. | INC-2026-001 | `Todo.Store.Migration.configureConnection` | `src/store/tests/Todo/Store/RegressionSpec.hs` |
| LESSON-004 | 타임아웃 설정이 모든 경합을 덮는다고 가정하지 않는다. SQLite의 busy handler는 저널 모드 전환과 지연 트랜잭션의 쓰기 승격에서 호출되지 않는다. 설계상 동시 접근이 정상 경로라면 유한 재시도를 정식 처리로 둔다. | INC-2026-001 | `Todo.Store.Migration.withBusyRetry` | `src/store/tests/Todo/Store/RegressionSpec.hs` |
| LESSON-005 | 프로세스 간 경합은 한 프로세스 안의 테스트로 재현되지 않는다. 같은 프로세스의 연결은 라이브러리 내부에서 직렬화되어 경합이 가려진다. 다중 프로세스 사용을 약속했다면 검증도 다중 프로세스로 해야 한다. | INC-2026-001 | 회귀 테스트 범주 | `tests/regression/README.md` |
| LESSON-002 | 제품이 약속한 사용 방식은 테스트가 그 방식으로 실행되어야 지켜진다. 표면을 늘리는 변경은 그 표면을 함께 실행하는 테스트를 함께 늘려야 한다. | INC-2026-001 | 회귀 테스트 범주 | `tests/regression/README.md` |

`LESSON-002`는 한 번 지키고 끝나는 항목이 아닙니다. 사고 당시 표면은 둘이었고 테스트도 둘이었습니다. `web`을 더하면서 회귀 테스트를 셋으로 늘린 것이 이 교훈의 두 번째 적용이며, 다음 표면이 생기면 같은 일을 다시 해야 합니다.

한 번의 사고에만 해당하는 세부 내용은 해당 사고 문서에 유지합니다. 교훈이 테스트나 정적 규칙으로 완전히 대체되면 이 문서는 그 실행 가능한 검증에 연결합니다.
