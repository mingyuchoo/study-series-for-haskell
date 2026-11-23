# hfm

hfm은 Haskell과 Brick으로 만든 두 패널 터미널 파일 관리자입니다. 두 디렉터리를 나란히 탐색하고, 반대편 패널을 기본 대상으로 파일을 복사하거나 이동할 수 있습니다. Emacs/Dired 키로 조작하며 텍스트 미리보기, 외부 편집기, 셸 명령 실행을 지원합니다.

## 빠른 시작

[Stack](https://docs.haskellstack.org/)을 설치한 뒤 이 디렉터리에서 대화형 터미널로 실행합니다. 프로젝트는 `stack.yaml`의 LTS 스냅샷으로 빌드합니다.

```bash
stack run hfm
stack run hfm -- "$HOME" /tmp
```

인자가 없으면 양쪽 패널이 현재 디렉터리에서 시작합니다. 경로 하나를 주면 왼쪽 패널에 적용하고, 두 개를 주면 왼쪽과 오른쪽에 차례대로 적용합니다.

Windows에서는 PowerShell에서 같은 Stack 명령을 실행하거나 프로젝트의 실행 스크립트를 사용합니다.

```powershell
.\scripts\run.ps1 run "C:\Users" "C:\Windows\Temp"
```

Linux와 macOS에서는 `./scripts/run.sh run`을 사용할 수 있습니다. 두 스크립트는 전달한 상대 경로를 호출 위치 기준으로 해석합니다. 경로를 생략하면 프로젝트 디렉터리에서 시작합니다.

## 기본 키

`C-`는 Ctrl, `M-`는 터미널의 Meta(주로 Alt), `RET`는 Enter입니다. `C-x o`처럼 키가 두 개면 순서대로 누릅니다.

| 키 | 동작 |
| --- | --- |
| `C-x o` | 활성 패널 전환 |
| `C-p` / `C-n`, ↑ / ↓ | 이전 / 다음 항목 또는 미리보기 한 줄 스크롤 |
| `M-v` / `C-v`, PgUp / PgDn | 이전 / 다음 페이지 |
| `M-<` / `M->`, Home / End | 탐색 목록 또는 미리보기의 처음 / 끝 |
| `RET`, `f`, `C-x C-f` | 디렉터리 열기 또는 파일 미리보기 |
| `^` | 상위 디렉터리로 이동 |
| `C-s` / `C-r` | 이름 검색 시작 또는 검색 중 다음 / 이전 결과로 이동 |
| `v` | 선택한 파일 미리보기 |
| `e` | 외부 편집기로 파일 열기 또는 디렉터리 이름 변경 |
| `C` / `R` | 복사 / 이동. 기본 대상은 반대편 패널의 디렉터리 |
| `r` / `+` | 이름 변경 / 디렉터리 생성 |
| `D` | 삭제 확인. `y` 또는 `Y`로 삭제 |
| `!` / `M-!` | 활성 패널 디렉터리에서 셸 명령 실행 |
| `M-o` / `g` | 숨김 항목 표시 전환 / 양쪽 패널 새로고침 |
| `F2` / `F3` / `F4` | 한국어·영어 전환 / 테마 선택 / 편집기 설정 |
| `C-g` / `C-x k` | 현재 입력 취소 또는 검색·미리보기 닫기 |
| `C-x C-c` | 종료 |

검색은 활성 패널에서 대소문자를 구분하지 않는 이름 부분 일치 필터입니다. `RET`로 필터를 유지한 채 탐색으로 돌아가고, `C-g`로 필터를 해제합니다. 입력란에서 `C-a` / `C-e`로 처음과 끝으로 이동하고, `C-a C-k`로 전체 입력을 지울 수 있습니다.

텍스트 미리보기는 파일 앞부분 64 KiB를 읽고 최대 100줄을 표시합니다. 인식 가능한 소스 파일에는 구문 강조를 적용하며, `q` 또는 Esc로 탐색 화면에 돌아갑니다.

복사와 이동은 기존 대상을 덮어쓰지 않습니다. 이동은 같은 파일 시스템에서 지원합니다. 디렉터리 삭제는 하위 항목을 포함해 즉시 이루어집니다. 심볼릭 링크를 복사하거나 삭제하면 링크 자체를 처리합니다. Windows에서 링크를 복사하려면 개발자 모드 또는 심볼릭 링크 생성 권한이 필요합니다.

## 설정과 외부 도구

- **언어**는 `F2`로 한국어와 영어를 전환합니다. 기본값은 한국어입니다.
- **테마**는 `F3` 키로 메뉴를 열고, 방향키나 `1`~`8`로 미리 본 뒤 `RET`로 적용합니다. 기본값은 Dark입니다.
- **편집기**는 탐색 화면에서 `F4`를 눌러 실행 파일 이름 또는 전체 경로를 입력하고 `RET`로 저장합니다. 저장된 편집기, `VISUAL`, `EDITOR`, 운영체제 기본값 순으로 선택합니다. 기본값은 Windows에서 `notepad.exe`, Linux와 macOS에서 `vi`입니다. 설정값에는 실행 파일만 입력합니다. 빈 값으로 저장하면 환경 변수와 기본값의 선택 순서를 따릅니다.
- **셸 명령**은 `!`로 입력창을 열고 `RET`로 실행합니다. Windows에서는 PowerShell, Linux와 macOS에서는 시스템 셸을 사용합니다. 명령 종료 후 Enter를 누르면 양쪽 패널을 새로고침하고 탐색 화면으로 돌아갑니다.

편집기·언어·테마 선택은 `settings.yaml`에 저장됩니다. 기본 위치는 Linux와 macOS에서 `~/.config/hfm/settings.yaml`, Windows에서 `%APPDATA%\hfm\settings.yaml`입니다. Linux와 macOS에서는 `XDG_CONFIG_HOME`을 지정하면 그 아래의 `hfm/settings.yaml`을 사용합니다.

```yaml
editor: nvim
language: ko
theme: dark
```

`editor`에는 `null`도 사용할 수 있습니다. 언어 값은 `ko`, `en`이고, 테마 값은 `light`, `dark`, `monokai`, `solarizedlight`, `solarizeddark`, `tomorrownightblue`, `gruvboxdark`, `gruvboxlight`입니다. 기존 `keybindings.yaml`의 `vim`이나 `vi` 값도 Emacs 키로 해석됩니다.

## 개발과 테스트

```bash
stack build
stack test
stack run hfm-check-architecture
bash scripts/test-run-scripts.sh
```

Linux와 macOS에서는 빌드 후 아래 명령으로 실제 키 입력을 가상 터미널(PTY)에서 검증할 수 있습니다. 이 검증에는 `stty`가 필요합니다.

```bash
stack exec hfm-test-keybindings -- "$(stack path --local-install-root)/bin/hfm"
```

`scripts/run.sh`와 `scripts/run.ps1`은 `format`, `lint`, `build`, `test`, `run`, `all`, `clean`, `help`를 지원합니다. 인자 없이 실행하면 포맷팅, 린트, 빌드, 테스트, 실행을 순서대로 수행합니다. 포맷팅은 `stylish-haskell`로 소스를 수정하고, 린트는 `hlint`를 사용합니다. 각 단계에서 사용하는 도구를 `PATH`에 추가하세요. Bash 스크립트는 x86 계열에서만 HLint를 실행합니다. PowerShell 스크립트 자체는 `pwsh -NoProfile -File scripts/test-powershell.ps1`로 검증할 수 있습니다.

| 경로 | 역할 |
| --- | --- |
| `apps/hfm/` | 실행 진입점과 의존성 조립 |
| `packages/hfm-domain/` | 파일 항목, 경로 정책, 선택, 입력 편집 등 순수 모델 |
| `packages/hfm-application/` | 순수 상태 전이, 실행 계획, I/O 포트와 실행기 |
| `packages/hfm-infrastructure/` | 파일 시스템, 프로세스, 설정의 I/O 구현 |
| `packages/hfm-tui/` | Brick/Vty 입력과 렌더링, 번역, 테마, 구문 강조 |
| `packages/hfm-dev-tools/` | 아키텍처 검사와 Unix PTY 검증 |

워크스페이스는 `stack.yaml`과 `cabal.project`에 정의되어 있습니다. 빌드 설정을 변경할 때는 각 패키지의 `package.yaml`을 수정하고 `stack build`로 `.cabal` 파일을 갱신합니다. 계층별 책임과 상태 전이는 [아키텍처 문서](docs/ARCHITECTURE.md)를 참고하세요.

## 배포 패키지 만들기

| 운영체제 | 명령 | 패키징 도구 |
| --- | --- | --- |
| Linux | `./scripts/release.sh deb` | `fpm`, `dpkg-deb` |
| Linux | `./scripts/release.sh rpm` | `fpm`, `rpmbuild`, `rpm` |
| macOS | `./scripts/release.sh dmg` | `hdiutil` |
| Windows | `.\scripts\release.ps1 nsis` | NSIS |

패키지는 `dist/release/`에 생성됩니다.

## 라이선스

[BSD 3-Clause](LICENSE)
