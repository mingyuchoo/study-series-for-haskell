# store Tests

실제 SQLite 파일을 대상으로 저장 계약과 과거 사고의 재발 여부를 검증합니다. 검증 대상 목록은 `../docs/invariants.md`에 있습니다.

```bash
cabal test store
```

## 규칙

- 데이터베이스는 항상 임시 디렉터리에 새로 만들고 실행 후 버립니다. 사용자의 `todo.db`를 건드리지 않습니다.
- 사고에서 배운 것은 `Todo.Store.RegressionSpec`에 최소 재현으로 남깁니다. 근거 사고는 `../../../docs/incidents/INDEX.md`에 있습니다.
- 동시성 테스트는 `-threaded`로 실행합니다. cabal 설정에 이미 반영되어 있습니다.
