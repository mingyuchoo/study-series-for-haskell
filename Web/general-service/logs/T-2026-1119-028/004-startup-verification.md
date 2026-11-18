# 기본 실행과 HTTP 검증

오케스트레이터가 포트 31028이 비어 있음을 확인한 뒤, 임시 디렉터리의 SQLite 데이터베이스를 `DATABASE_PATH`로 지정하고 `scripts/run.sh`를 기본 옵션으로 실행했다. 기존 DB와 서버 프로세스는 사용하지 않았다.

- 포맷·린트·빌드·테스트 단계와 서버 시작을 완료했다.
- 전체 기본 실행 로그에서 HLint `No hints`와 GHC 경고 없음이 확인됐다.
- Haskell 테스트 24개와 Elm 테스트 18개가 통과했다.
- `GET /`가 HTTP 200을 반환하고 Elm 초기화 코드를 포함했다.
- `GET /api/task`가 HTTP 200을 반환했으며 예시 Task 3개와 `Draft`, `Reviewed`, `Approved` 상태를 확인했다.
- 검증용 프로세스를 종료하고 임시 데이터베이스를 정리했다. 포트 31028이 해제됐다.
- 최종 `git diff --check`가 통과했다.

기본 실행 로그는 `/tmp/general-service-028-startup.log`에 저장했다. macOS와 Windows에서는 직접 실행하지 않았다.
