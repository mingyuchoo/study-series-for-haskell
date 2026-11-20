# git-puller

지정한 디렉터리에서 Git 작업 트리를 찾아 병렬로 fast-forward 업데이트하고, 결과를 경로순으로 출력합니다. OCaml 구현(`../git-puller`)을 Haskell로 옮긴 것으로, 명령과 출력 형식이 같습니다.

```sh
git-puller --dry-run ~/projects
git-puller --verbose ~/projects
git-puller --jobs 16 ~/projects
git-puller -- -projects
```

`--dry-run`은 로컬 상태만 검사합니다. `--jobs <count>`는 동시에 처리할 저장소 수이며 기본값은 16입니다. 디렉터리 탐색, 저장소 검사, pull이 모두 이 개수만큼 동시에 진행되며, 각 저장소는 검사가 끝나는 즉시 pull을 시작합니다. 같은 Git 공통 디렉터리를 공유하는 연결된 worktree는 서로 순차로 업데이트합니다. 종료 코드 0은 실패 없는 완료, 1은 경로별 실패, 2는 시작 오류를 뜻합니다. 실제 업데이트에는 Git과 원격 인증 설정이 필요합니다.

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

- `packages/domain` (`git-puller-domain`)은 부수효과가 없는 도메인 모델입니다. 상태는 ADT로, 규칙은 순수 전이 함수로 표현합니다.
  - `Discovery`는 디렉터리 탐색 상태 머신입니다. 상태는 `Exploring 디렉터리들 | Complete 후보들`이고 `afterListings`가 한 단계의 목록 결과를 모두 받아 다음 상태를 계산합니다. 한 상태가 요구하는 디렉터리들은 서로 독립이라 동시에 나열할 수 있습니다.
  - `Update`는 작업 트리 하나의 수명 주기 상태 머신입니다. `transition :: Mode -> Phase -> Signal -> Phase`가 `AwaitingInspection → AwaitingPull → Settled` 사이의 전이를 결정하며, 현재 단계가 기다리지 않는 신호는 상태를 바꾸지 않습니다.
  - `Repository`는 저장소 상태와 업데이트 가능 여부, `Outcome`은 결과 집계를 담당합니다.
- `packages/application` (`git-puller-application`)은 DCI 관점으로 유스케이스를 구성합니다.
  - Data는 도메인 패키지의 값입니다.
  - Context는 `UpdateWorktrees`입니다. `start`가 상호작용을 엮어 유스케이스 전체를 순수한 `Program` 값으로 만들고, `perform`이 각 `Request`를 그 요청에 답하는 역할에 연결합니다.
  - Interaction은 `Interaction.Survey`(탐색)와 `Interaction.Update`(검사와 pull)입니다. 도메인 상태 머신의 현재 상태를 보고 필요한 요청을 보낸 뒤 응답을 신호로 되돌려 줍니다.
  - Role은 `Roles`의 `Surveyor`, `Inspector`, `Updater`, `Observer`이며 `Cast`가 한 번의 실행에 참여하는 역할 수행자를 묶습니다. 효과 타입에 대해 다형적이어서 테스트에서는 순수한 수행자로 대체합니다.
  - `Program`은 응답 타입이 정해진 `Request`(GADT)와 연속으로 이루어진 순수한 작업 기술이고, 서로 독립인 작업은 `Concurrently`로, 같은 자원을 두고 겹치면 안 되는 작업은 `Exclusively`로 표시합니다. pull은 공통 디렉터리를 자원으로 삼아 `Exclusively`로 감쌉니다.
- `packages/infrastructure` (`git-puller-infrastructure`)는 `Program`을 작업자 풀로 해석하고 Git, 파일시스템, 자식 프로세스, 터미널에 접근합니다. 부수효과는 이 패키지와 실행 파일의 `Main`에만 있습니다. 저장소 하나의 검사는 `git rev-parse` 한 번과 `git status --porcelain=v2 --branch` 한 번으로 끝나며, 출력 해석은 순수 모듈 `GitOutput`이 맡습니다. 자식 프로세스를 띄울 때 상속된 디스크립터를 모두 닫는 비용이 열린 파일 한도에 비례하므로, 시작할 때 `Descriptors`가 소프트 한도를 작업 수에 맞는 값(최소 1024)으로 낮춥니다.
- `apps/git-puller` (`git-puller`)는 CLI 옵션을 해석하고 출력 문자열을 만들며 역할에 어댑터를 배정합니다. 진행률 표시도 `Cli.Progress`의 상태 머신(`Surveying | Working`)과 순수 전이 함수로 계산하고, `Main`은 그 결과를 터미널에 쓰기만 합니다.

의존성은 `apps → infrastructure → application → domain` 한 방향으로만 흐릅니다.

테스트는 패키지마다 hspec 스위트로 두었습니다. 도메인 상태 머신과 CLI 해석·렌더링·진행률은 단위 테스트, 애플리케이션은 `Program`의 순수 해석기, 인프라는 역할 대역과 실제 자식 프로세스, CLI는 `apps/git-puller/test/cli.sh`가 로컬 Git 저장소와 PTY로 검증합니다.

## 배포

Linux에서는 `bash scripts/release.sh`로 tar.gz, deb, rpm을 만듭니다. macOS의 같은 명령은 tar.gz와 pkg를 만듭니다. 번들만 필요하면 `bash scripts/release.sh --bundle-only`를 사용합니다. 릴리스 버전은 `apps/git-puller/git-puller.cabal`의 `version:` 필드에서 읽습니다. 빌드 호스트의 시스템 라이브러리 버전에 맞는 대상에서 사용합니다. 설치된 실행 파일은 `bash apps/git-puller/test/installed.sh <실행 파일>`로 확인할 수 있습니다.

Windows WSL용 ZIP과 설치 프로그램은 PowerShell의 `scripts/release.ps1`로 빌드합니다. 빌드에는 WSL의 GHC 9.10.3 도구 체인과 Windows Inno Setup이 필요합니다. 설치 후 `git-puller.ps1`에 WSL 경로를 전달합니다.
