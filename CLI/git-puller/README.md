# git-puller

지정한 디렉터리에서 Git 작업 트리를 찾아 병렬로 fast-forward 업데이트하고, 결과를 경로순으로 출력합니다. OCaml 구현(`../git-puller`)을 Haskell로 옮긴 것으로, 명령과 출력 형식이 같습니다.

```sh
git-puller --dry-run ~/projects
git-puller --verbose ~/projects
git-puller --jobs 16 ~/projects
git-puller -- -projects
```

`--dry-run`은 로컬 상태만 검사합니다. `--jobs <count>`는 동시에 처리할 저장소 수이며 기본값은 8입니다. 같은 Git 공통 디렉터리를 공유하는 연결된 worktree는 서로 순차로 업데이트합니다. 종료 코드 0은 실패 없는 완료, 1은 경로별 실패, 2는 시작 오류를 뜻합니다. 실제 업데이트에는 Git과 원격 인증 설정이 필요합니다.

## 빌드 및 테스트

GHC 9.10.3과 cabal-install 3.12 이상이 필요합니다.

```sh
cabal update
cabal build all
cabal test all
cabal run git-puller -- --help
```

`bash scripts/run.sh [인수...]`는 fourmolu 포맷, hlint, 빌드, 테스트를 차례로 수행한 뒤 CLI를 실행합니다.

다른 구현과 출력을 비교하려면 `REFERENCE_GIT_PULLER`에 기준 실행 파일의 절대 경로를 지정합니다.

```sh
REFERENCE_GIT_PULLER="$PWD/../git-puller/_build/default/apps/git-puller/main.exe" \
  bash apps/git-puller/test/cli.sh "$(cabal list-bin exe:git-puller)"
```

## 워크스페이스 구조

`cabal.project` 하나가 네 패키지를 묶습니다. 계층 사이의 의존성은 각 `.cabal` 파일의 `build-depends`에 선언한 패키지 이름으로만 연결됩니다.

- `packages/domain` (`git-puller-domain`)은 저장소 상태, 업데이트 가능 여부, 결과 집계를 모델링합니다. `PullPlan`은 공통 디렉터리가 같은 작업 트리를 순차 그룹으로 묶습니다. `Update`의 순수 전이 함수는 검사 결과와 실행 모드로 건너뛰기, 계획, pull 요청을 결정합니다.
- `packages/application` (`git-puller-application`)의 `Batch`는 작업 흐름 전체를 순수한 `Program` 값으로 기술합니다. 각 단계는 응답 타입이 정해진 `Request`(GADT)와 다음 상태를 계산하는 연속으로 표현되고, 서로 독립인 작업은 `Concurrently`로 표시하며 동시 실행 방식은 실행기가 결정합니다. `Ports`는 실행기가 채워야 하는 포트를 효과 타입에 대해 다형적인 레코드로 정의합니다.
- `packages/infrastructure` (`git-puller-infrastructure`)는 `Program`을 작업자 풀로 해석하고 Git, 파일시스템, 자식 프로세스, 터미널에 접근합니다. 인프라는 애플리케이션과 도메인에 의존하며, 애플리케이션은 도메인에 의존합니다.
- `apps/git-puller` (`git-puller`)는 CLI 옵션을 해석하고 출력 문자열을 만들며 실행기에 어댑터를 연결합니다.

테스트는 패키지마다 hspec 스위트로 두었습니다. 도메인과 CLI 해석·렌더링은 단위 테스트, 애플리케이션은 `Program`의 순수 해석기, 인프라는 포트 대역과 실제 자식 프로세스, CLI는 `apps/git-puller/test/cli.sh`가 로컬 Git 저장소와 PTY로 검증합니다.

## 배포

Linux에서는 `bash scripts/release.sh`로 tar.gz, deb, rpm을 만듭니다. macOS의 같은 명령은 tar.gz와 pkg를 만듭니다. 번들만 필요하면 `bash scripts/release.sh --bundle-only`를 사용합니다. 릴리스 버전은 `apps/git-puller/git-puller.cabal`의 `version:` 필드에서 읽습니다. 빌드 호스트의 시스템 라이브러리 버전에 맞는 대상에서 사용합니다. 설치된 실행 파일은 `bash apps/git-puller/test/installed.sh <실행 파일>`로 확인할 수 있습니다.

Windows WSL용 ZIP과 설치 프로그램은 PowerShell의 `scripts/release.ps1`로 빌드합니다. 빌드에는 WSL의 GHC 9.10.3 도구 체인과 Windows Inno Setup이 필요합니다. 설치 후 `git-puller.ps1`에 WSL 경로를 전달합니다.
