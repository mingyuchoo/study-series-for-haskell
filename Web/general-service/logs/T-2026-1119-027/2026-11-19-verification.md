# 실행 스크립트 검증

1. 커밋 버전의 npm 매니페스트와 잠금 파일을 임시 디렉터리에서 복원했다. `npm ci`는 `elm-test 0.19.3-1`의 tarball 요청에서 HTTP 404로 종료했다.
2. 작업 트리에 이미 적용된 `elm-test 0.19.3-0`으로 `./scripts/run.sh --check-only`가 통과했다. Haskell 24개, Elm 18개 테스트가 통과했다.
3. reviewer가 두 npm 파일과 실제 설치 버전의 일치를 확인하고 의존성 수정을 승인했다.
4. 포트 3000이 비어 있음을 확인한 뒤 임시 SQLite 데이터베이스를 사용해 `./scripts/run.sh`로 시작했다. 루트 URL의 정상 응답을 확인한 후 검증 프로세스를 종료했다.
