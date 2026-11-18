# 실행 경고 수정 결과

## 원인과 변경

`scripts/run.sh --check-only`에서 HLint 제안 13건과 GHC 경고 2건을 재현했다. HLint의 `Maybe` 처리, 불필요한 인자, 조건문, Functor 표현을 동등한 표준 함수와 Applicative 표현으로 정리했다. SQLite Task 행 파서는 기존 11개 필드 순서와 열거형 검증을 유지한다.

`SQLiteUserRepository`의 미사용 `Data.Text` import를 제거했다. `FromRow User` orphan 인스턴스는 같은 인프라 모듈에 정의한 `UserRow` 래퍼의 인스턴스로 교체했다. 네 사용자 조회에서 래퍼를 해제하므로 도메인은 SQLite에 의존하지 않는다.

참조가 없는 `src/Lib.hs`와 `package.yaml`·`GeneralService.cabal`의 모듈 노출을 제거했다. Elm의 `urgencyOption`, `importanceOption` 및 관련 타입 import도 제거했다. 테스트에서 사용하는 메모리 저장소는 유지했다. 실행 스크립트와 경고 옵션은 변경하지 않았다.

## 검증

- 수정 전 HLint: 13 hints, 직접 실행 종료 코드 1.
- 수정 후 HLint: `No hints`, 직접 실행 종료 코드 0.
- `scripts/run.sh --check-only`: 종료 코드 0.
- Haskell 전체 모듈 재컴파일: GHC 경고 2건에서 0건으로 감소.
- Haskell 테스트 24개, Elm 테스트 18개 통과. Haskell·Elm 빌드 성공.
- 삭제한 모듈·함수의 남은 소스 참조 없음.
- `git diff --check` 통과.

재현 로그는 `/tmp/general-service-028-before.log`, 수정 후 전체 검증 로그는 `/tmp/general-service-028-after.log`에 저장했다. HLint 단독 실행 로그는 `/tmp/general-service-028-hlint-before.log`와 `/tmp/general-service-028-hlint-after.log`에 저장했다.
