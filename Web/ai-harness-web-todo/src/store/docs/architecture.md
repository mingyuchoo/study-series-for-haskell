# store Architecture

## Boundaries

- 도메인 상태 기계와 저장 어댑터를 분리합니다. 이 패키지는 상태 전이를 판단하지 않고 주어진 값을 저장합니다.
- 스키마 원본은 `../schema/schema.sql` 하나입니다. Haskell 코드는 이 파일을 임베드하며 복사본을 두지 않습니다.
- 인코딩과 디코딩은 `Todo.Store.Sqlite`에 모읍니다. 시각과 날짜의 문자열 형식이 여기서만 결정됩니다.
- 쓰기는 트랜잭션 안에서 수행합니다. 할 일 행과 태그 행이 따로 커밋되지 않게 하기 위함입니다.

## Connection Settings

| 설정 | 값 | 이유 |
|---|---|---|
| `journal_mode` | WAL | 세 표면의 동시 접근 (`../../../docs/incidents/INC-2026-001.md`) |
| `busy_timeout` | 5000ms | 짧은 경합에서 즉시 실패하지 않게 함 |
| `foreign_keys` | ON | 태그 정리를 참조 무결성에 맡김. SQLite는 연결마다 켜야 합니다 |

## PRAGMA 적용 순서

`configureConnection`은 `busy_timeout`을 가장 먼저 설정합니다.

저널 모드를 WAL로 바꾸는 것 자체가 배타적 잠금을 요구합니다. 두 프로세스가 같은 파일을 동시에 처음 열면 한쪽이 그 잠금에서 경합하는데, 그 시점에 timeout이 아직 0이면 대기 없이 `SQLITE_BUSY`로 실패합니다. 설정을 뒤에 두면 정작 그 설정이 필요한 작업이 보호받지 못합니다.

이 순서는 `web`과 `api`를 한 명령으로 함께 띄우면서 드러났습니다. 두 서버가 빈 파일을 동시에 초기화하며 둘 다 죽었습니다. 검증은 `../tests/Todo/Store/RegressionSpec.hs`의 "동시에 처음 열어도" 사례입니다.

## busy_timeout이 덮지 못하는 경합

순서를 고쳐도 프로세스 두 개가 **없던 파일**을 동시에 처음 열면 여전히 실패했습니다. 15회 중 6회 재현되었습니다.

`busy_timeout`은 잠금 대기를 busy handler로 처리하지만, SQLite가 busy handler를 부르지 않는 경우가 있습니다.

| 경우 | 이유 |
|---|---|
| 저널 모드 전환 (`PRAGMA journal_mode = WAL`) | 배타적 잠금이 필요한데 handler를 거치지 않고 즉시 `SQLITE_BUSY`를 돌려줍니다. 빈 데이터베이스는 기본이 `delete` 모드이므로 첫 기동마다 전환이 일어납니다 |
| 지연 트랜잭션의 쓰기 승격 | 읽기 스냅숏을 잡은 뒤 쓰기로 올라갈 때, 대기가 교착으로 이어질 수 있어 즉시 실패시킵니다 |

두 가지를 함께 적용했습니다.

- `applySchema`가 `withImmediateTransaction`을 씁니다. 쓰기 잠금을 처음부터 잡아 승격 자체를 없앱니다.
- `openStore`가 설정과 스키마 적용을 `withBusyRetry`로 감쌉니다. 지수적으로 늘어나는 지연으로 최대 10회, 합계 약 2.5초까지 다시 시도한 뒤 원래 오류를 올립니다.

재시도가 우회책이 아니라 정식 처리인 이유는, 두 표면을 함께 띄우는 것이 이 제품의 설계이기 때문입니다(`../../../docs/product/vision.md`). 기동 경합은 예외 상황이 아니라 정상 경로입니다.

프로세스 간 경합은 한 테스트 프로세스 안에서 재현되지 않습니다. 같은 프로세스의 연결들은 SQLite 내부에서 직렬화되어 경합이 가려집니다. 그래서 회귀 테스트는 재시도 기제를 직접 검증하고, 실제 경합은 아래 절차로 수동 확인합니다.

### 수동 확인 절차

```bash
rm -f /tmp/race.db /tmp/race.db-wal /tmp/race.db-shm
```

```bash
./scripts/run.sh web --with-api --db /tmp/race.db --port 8190 --api-port 8191
```

파일을 지우고 다시 띄우기를 열 번 이상 반복해 `ErrorBusy`가 나오지 않는지 봅니다.

## Migration

`schema_version` 표에 적용된 버전을 기록합니다. 현재 버전은 1이며 되돌리는 경로가 없습니다. 이 한계는 `../../../docs/tech-debt/active.md`의 `TD-001`로 관리합니다.

## Verification

`cabal test store`가 실제 임시 SQLite 파일을 대상으로 실행됩니다.
