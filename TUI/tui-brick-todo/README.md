# tto

터미널 기반 할 일 관리 애플리케이션 (Brick + SQLite + Tagless Final 패턴)

## How to create a project

```bash
stack new <project-name> mingyuchoo/cli
```

## How to build

```bash
stack build
# or
stack build --fast --file-watch --ghc-options "-j4 +RTS -A128m -n2m -RTS"
```

## How to test as watch mode

```bash
stack test --fast --file-watch --watch-all
# or
stack test --coverage --fast --file-watch --watch-all --haddock
# or
ghcid --command "stack ghci test/Spec.hs"
```

## How to run

```bash
stack run
```
You can also use `Makefile` for these works.

## 포맷팅부터 실행까지

Stack, Fourmolu, HLint가 PATH에 있어야 합니다. Stack 설치 후 필요한 도구를 설치합니다.

```bash
stack install fourmolu hlint
```

Linux/macOS에서는 다음 명령을 사용합니다.

```bash
./scripts/run.sh
```

PowerShell에서는 다음 명령을 사용합니다.

```powershell
.\scripts\run.ps1
```

스크립트는 프로젝트 루트로 이동하여 Haskell 파일을 포맷팅한 뒤 린팅, 빌드,
테스트를 순서대로 수행하고 `tto-exe`를 실행합니다. 어느 단계든 실패하면 즉시
중단합니다. 스크립트에 전달한 인자는 애플리케이션에 전달됩니다.
마지막 단계는 대화형 터미널이 필요하며, `q` 또는 `Esc`로 종료합니다.

## 릴리스 번들과 설치파일 생성

릴리스 스크립트는 Fourmolu 포맷팅 → HLint 린팅 → 최적화 빌드(`-O2`) →
테스트 → 번들링 → 설치파일 생성을 수행합니다. 소스 파일은 직접 포맷팅되며,
실패한 단계가 있으면 중단합니다. 설치파일 생성까지 성공한 결과를 기본 경로인
`dist/release/tto-<version>-<platform>-<architecture>/`에 배치합니다.
이미 존재하는 릴리스 디렉터리는 보존하고 오류로 중단합니다. 같은 버전을 다시
생성하려면 다른 출력 경로를 지정합니다. 애플리케이션 실행이나 시스템 설치는
수행하지 않습니다.

공통으로 Stack과 프로젝트 빌드에 필요한 C 개발 도구·라이브러리,
PATH에 등록된 Fourmolu·HLint가 필요합니다.

```bash
stack setup
stack install fourmolu hlint
```

### Linux

Debian/Ubuntu에서 `.deb`와 `.rpm`을 모두 만들려면 다음 도구를 설치합니다.

```bash
sudo apt-get install build-essential pkg-config libgmp-dev zlib1g-dev libtinfo-dev dpkg-dev rpm
./scripts/release.sh
```

`.deb`에는 `dpkg-deb`, `dpkg-shlibdeps`가 필요하며, `.rpm`에는 `rpmbuild`가
필요합니다. 필요한 형식만 지정하면 해당 패키징 도구만 검사합니다.
Fedora/RHEL에서는 `rpm-build`와 프로젝트 개발 라이브러리를 설치한 뒤
`--package rpm`을 사용합니다. `.deb` 생성은 Debian 계열 빌드 환경에서 실행합니다.

```bash
./scripts/release.sh --package deb
./scripts/release.sh --package rpm --output-dir ./artifacts
./scripts/release.sh --help
```

결과는 `tto-<version>-linux-<architecture>.tar.gz`, `.deb`, `.rpm`입니다.
설치 패키지는 `/usr/bin/tto`와 `/usr/share/tto/config/`를 제공하고,
공유 라이브러리 의존성을 자동으로 기록합니다.

```bash
sudo apt install ./dist/release/tto-0.1.0.0-linux-aarch64/tto-0.1.0.0-linux-aarch64.deb
```

아키텍처는 실제 GHC 타깃에서 결정하며 `x86_64`, `aarch64`를 지원합니다.
`.deb` 메타데이터에는 각각 `amd64`, `arm64`를 사용합니다.
설치 패키지와 압축 번들은 빌드 환경의 libc 등 시스템 라이브러리와 호환되는
배포판을 대상으로 합니다. RPM 파일을 생성해도 다른 배포판용으로 재컴파일되지는
않습니다. 배포 대상 배포판과 지원할 가장 오래된 환경에서 각각 빌드하세요.

### macOS

Xcode Command Line Tools의 `pkgbuild`, `codesign`과 Homebrew의
`dylibbundler`가 필요합니다.

```bash
xcode-select --install
brew install dylibbundler
./scripts/release.sh
```

결과는 `tto-<version>-macos-<architecture>.tar.gz`, `.pkg`입니다.
외부 dylib는 번들에 복사하고 참조 경로를 수정하며 ad-hoc 서명을 적용합니다.
`.pkg`는 `/usr/local/bin/tto`, `/usr/local/lib/tto/` 및
`/usr/local/share/tto/config/`에 설치합니다. `x86_64`, `arm64`를 지원하며
각 아키텍처의 macOS에서 별도로 빌드합니다. 배포자 인증서 서명과 Apple 공증은
별도 작업입니다.

### Windows 11

Windows PowerShell 5.1 이상, 네이티브 Windows용 Stack/GHC,
Stack 실행 환경에서 사용할 수 있는 GNU `objdump`와 `where.exe`,
Inno Setup 6.3 이상이 필요합니다. `ISCC.exe`를 PATH에 추가하거나
`-InnoSetupCompiler`로 지정합니다.

```powershell
.\scripts\release.ps1
.\scripts\release.ps1 -OutputDir .\artifacts -InnoSetupCompiler 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
```

결과는 `tto-<version>-windows-<architecture>.zip`,
`tto-<version>-windows-<architecture>-setup.exe`입니다. 실행파일이 참조하는
비시스템 DLL을 재귀적으로 수집하며, 찾지 못한 DLL이 있으면 실패합니다.
설치 프로그램은 관리자 권한 없이 `%LOCALAPPDATA%\Programs\tto`에 설치하고
시작 메뉴 바로가기와 제거 프로그램을 만듭니다. 터미널에서 직접 실행할 때는
설치 폴더의 `bin\tto.exe`를 사용합니다. PATH는 자동 변경하지 않습니다.
설치 프로그램은 Windows 11 이상을 대상으로 하며 배포자 서명은 별도 작업입니다.

### 번들 내용과 검증

버전은 `package.yaml`에서 읽습니다. 번들에는 `bin/`, 설정 예제
`share/tto/config/`, 라이선스·문서 `share/doc/tto/`만 포함하며,
사용자의 `todos.db`와 기존 설정은 포함하지 않습니다. 애플리케이션은
`~/.config/tto`(Windows: `%USERPROFILE%\.config\tto`)를 사용하므로,
필요한 YAML 예제를 그 경로에 복사해 설정합니다.

각 OS에서 스크립트를 실행해야 하며 교차 컴파일은 수행하지 않습니다.
`--output-dir`와 `-OutputDir`의 상대 경로는 호출한 디렉터리를 기준으로 합니다.
출력 경로 아래에 OS·아키텍처·버전별 디렉터리가 생성됩니다.
`SHA256SUMS`는 해당 실행에서 만든 파일만 기록합니다.

```bash
cd dist/release/tto-0.1.0.0-linux-aarch64
sha256sum -c SHA256SUMS
```

macOS에서는 `shasum -a 256 -c SHA256SUMS`, Windows에서는
`Get-FileHash -Algorithm SHA256 <파일>`로 검증할 수 있습니다.

Linux 패키징 통합 테스트는 Python 3와 GCC, Debian/RPM 패키징 도구를 사용합니다.
느린 Haskell 도구 실행을 테스트 대역으로 치환하고 실제 `.deb`·`.rpm`과
압축파일의 내용, 의존성, 체크섬, 실패 시 결과 보존을 검사합니다.
`pwsh`가 있으면 Windows 명령 경계를 치환한 PowerShell 동작 테스트도 실행합니다.
이 테스트는 Windows 설치 프로그램의 실제 컴파일·설치 검증을 대신하지 않습니다.

```bash
python3 scripts/test_release.py -v
```

## 아키텍처

### 모듈 구조

- **TodoStatus**: GADT 기반 타입 안전한 상태 머신 (`Registered → InProgress → Cancelled → Completed → Registered`)
- **Effects**: Tagless Final 효과 대수 (`MonadTodoRepo`, `MonadConfig`, `MonadI18n`, `MonadTime`)
- **App**: Tagless Final 해석기 (ReaderT + IO)
- **TodoService**: 순수 비즈니스 로직 (입력 검증, 타입 안전한 상태 전이 디스패치)
- **DB**: SQLite 데이터베이스 연산
- **UI.Types**: UI 데이터 타입 및 렌즈
- **UI.Draw**: 순수 렌더링 함수 (상태 헬퍼 함수로 중복 제거)
- **UI.Events**: 이벤트 핸들러 (에러 피드백 메커니즘 포함)
- **UI.Attributes**: 터미널 UI 속성 정의
- **Config**: YAML 기반 키바인딩 설정
- **I18n**: 다국어 지원 (한국어/영어)

### 주요 설계 원칙

- **타입 안전성**: GADT를 통한 컴파일 타임 상태 전이 검증, `AnyStatus` 패턴 매칭을 통한 런타임 디스패치
- **효과 분리**: Tagless Final 패턴으로 순수 비즈니스 로직과 IO 분리
- **에러 피드백**: DB 작업 실패 시 UI에 에러 메시지 표시 (조용한 실패 방지)
- **입력 검증**: `createNewTodo`에서 빈 action 검증 (`Maybe TodoId` 반환)

## 키바인딩 설정

TUI Todo Manager는 사용자 정의 키바인딩을 지원합니다.

### 설정 파일

키바인딩 설정은 `config/keybindings.yaml` 파일에서 관리됩니다.

### 기본 키바인딩

- `q` 또는 `Esc`: 애플리케이션 종료
- `a`: 새 할 일 추가
- `e`: 할 일 편집
- `Space`: 할 일 상태 순환 토글
- `d`: 할 일 삭제
- `↑` 또는 `k`: 위로 이동
- `↓` 또는 `j`: 아래로 이동

### 키바인딩 커스터마이징

`config/keybindings.yaml` 파일을 수정하여 원하는 키를 설정할 수 있습니다.

예시 - Vim 스타일 키바인딩:
```yaml
keybindings:
  quit: ['q']
  add_todo: ['i', 'a']
  toggle_complete: ['Space', 'x']
  delete_todo: ['d']
  navigate_up: ['k', 'Up']
  navigate_down: ['j', 'Down']
  save_input: ['Enter']
  cancel_input: ['Esc']
```

자세한 설정 방법은 `config/README.md`를 참조하세요.

### 예시 설정 파일

- `config/keybindings.yaml`: 기본 키바인딩
- `config/keybindings-vim.yaml`: Vim 스타일 키바인딩 예시
