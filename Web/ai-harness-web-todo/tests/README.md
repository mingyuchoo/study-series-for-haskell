# Repository Test Strategy

이 저장소의 실행 가능한 테스트는 각 패키지의 `tests` 디렉터리 안에 있습니다. Haskell 테스트 스위트는 cabal 패키지에 속해야 하므로 실행 코드를 여기에 두지 않습니다.

이 디렉터리는 **각 테스트 범주가 무엇을 책임지고 실제로 어디서 실행되는지**를 기록합니다. 범주와 실행 위치가 어긋나면 검증이 있다고 착각하기 쉽습니다.

| 범주 | 문서 | 실행 위치 |
|---|---|---|
| 단위 | `unit/README.md` | `../src/core/tests`, `../src/cli/tests`, `../src/web/tests` |
| 통합 | `integration/README.md` | `../src/store/tests` |
| 계약 | `contract/README.md` | `../src/api/tests` |
| 아키텍처 | `architecture/README.md` | `../scripts/quality/architecture-check.sh` |
| 보안 | `security/README.md` | `../src/api/tests`, `../src/web/tests` |
| 회귀 | `regression/README.md` | `../src/store/tests` |

## 전체 실행

```bash
cabal test all
```

```bash
./scripts/quality/architecture-check.sh
```

## 원칙

- 테스트는 시계, 네트워크, 사용자 홈 디렉터리에 의존하지 않습니다. 데이터베이스가 필요한 테스트는 임시 디렉터리에 새 파일을 만들고 실행 후 버립니다.
- 문서에 적은 규칙은 가능하면 이 중 하나의 범주에 실행 가능한 형태로 존재해야 합니다.
- 사고에서 배운 것은 회귀 테스트로 남깁니다.
