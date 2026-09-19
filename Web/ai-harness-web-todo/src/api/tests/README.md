# api Tests

게시한 API 계약과 입력 검증을 검증합니다. 검증 대상 목록은 `../docs/invariants.md`에 있습니다.

```bash
cabal test api
```

## 구성

| 파일 | 책임 |
|---|---|
| `Todo/Api/Harness.hs` | 임시 데이터베이스와 WAI 요청 도구 |
| `Todo/Api/ContractSpec.hs` | `../../../docs/contracts/api/TODO-API-v1.md`의 약속 |
| `Todo/Api/SecuritySpec.hs` | 입력 검증과 오류 노출 범위 |

## 규칙

- 실제 포트를 열지 않습니다. `Network.Wai.Test`로 애플리케이션에 직접 요청합니다.
- 데이터베이스는 임시 디렉터리에 새로 만들고 실행 후 버립니다.
- `ContractSpec`이 실패하면 테스트를 고치기 전에 계약 문서와 버전 정책을 먼저 확인합니다.
