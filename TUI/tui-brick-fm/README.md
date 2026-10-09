# hfm 터미널 파일 관리자

Brick으로 만든 두 패널 터미널 파일 관리자입니다. Midnight Commander처럼 좌우 디렉터리를 나란히 보며 탐색하고 파일을 복사하거나 이동할 수 있습니다.

## 실행

```bash
stack build
stack run hfm-exe
stack run hfm-exe -- /path/to/left /path/to/right

# 같은 실행을 scripts에서
./scripts/run.sh run /path/to/left /path/to/right
```

Windows 11에서는 Windows용 Stack/GHC를 설치한 뒤 PowerShell에서 직접 실행합니다. WSL이나 Bash는 필요하지 않습니다.

```powershell
.\scripts\run.ps1                  # 빌드 후 실행
.\scripts\run.ps1 run C:\Users C:\Temp
.\scripts\run.ps1 build
.\scripts\run.ps1 test             # Python도 필요
.\scripts\run.ps1 all              # 빌드, 검사, 테스트, 실행
.\scripts\run.ps1 clean
```

인자가 없으면 양쪽 패널 모두 현재 디렉터리에서 시작합니다. 스크립트는 프로젝트 루트에서 Stack을 실행하므로 인자를 생략하면 프로젝트 루트가 시작 위치입니다. 인자 하나만 주면 왼쪽 패널만 해당 경로에서 시작합니다. 스크립트에 전달한 상대 경로는 호출한 위치를 기준으로 해석합니다. 실행에는 대화형 터미널이 필요하며, Windows는 네이티브 콘솔을, Unix는 `/dev/tty`를 사용합니다. Windows에서 심볼릭 링크 복사에는 개발자 모드 또는 링크 생성 권한이 필요합니다.

## 키

모든 화면에서 Emacs 방식의 키를 사용합니다. `C-`는 Ctrl, `M-`는 Meta(터미널의 Alt/Option), `RET`는 Enter입니다. 파일 작업은 Emacs Dired의 문자 명령을 따릅니다.

| 키 | 동작 |
|---|---|
| `C-x o` | 활성 패널 전환 (탐색 화면) |
| `C-p` / `C-n` (`↑` / `↓`) | 이전 / 다음 항목, 보기 화면에서는 한 줄 스크롤 |
| `C-v` / `M-v` (`PgDn` / `PgUp`) | 다음 / 이전 페이지 (화면 높이 기준) |
| `M-<` / `M->` | 목록 또는 보기의 처음 / 끝 |
| `RET`, `f`, `C-x C-f` | 선택한 디렉터리 열기 또는 파일 보기 |
| `^` | 상위 디렉터리 |
| `C-s` / `C-r` | 현재 패널 이름 검색 시작, 검색 중 다음 / 이전 결과 이동 |
| `v` | 파일 보기 (최대 64 KiB) |
| `e` | 선택한 파일을 외부 편집기로 편집. 디렉터리를 선택하면 이름 변경 |
| `C` | 복사. 기본 대상은 반대 패널 디렉터리 |
| `R` | 이동 또는 이름 변경. 기본 대상은 반대 패널 디렉터리 |
| `r` | 파일·디렉터리 이름 변경. 현재 이름으로 입력 시작 |
| `+` | 디렉터리 만들기 |
| `D` | 선택 항목 삭제 확인. `y`/`Y`로 실행, 다른 키로 취소 |
| `!` / `M-!` | 현재 활성 패널 디렉터리에서 셸 명령 실행 |
| `M-o` | 숨김 파일 표시 전환 (hfm 확장 명령) |
| `g` | 두 패널 새로고침 |
| `F2` | 한국어/영어 메뉴 전환 |
| `F3` | 테마 선택 메뉴 열기·닫기 |
| `C-x C-c` | 모든 화면에서 종료 |
| `C-g` | 검색 해제, 입력·삭제 취소, 파일 보기 닫기, 접두 명령 취소 |
| `C-x k` | 현재 검색·입력·보기 닫기 |

검색과 경로 입력에서는 `C-a`/`C-e`로 처음/끝, `C-b`/`C-f`로 한 글자, `M-b`/`M-f`로 한 단어씩 커서를 옮깁니다. `C-h`/Backspace와 `C-d`/Delete는 커서 앞/뒤 글자를 지우고, `C-k`는 커서부터 끝까지 지웁니다. `M-Backspace`와 `M-d`는 앞/뒤 단어를 지웁니다. 기존 `C-w`도 앞 단어 삭제의 별칭으로 사용할 수 있습니다. 전체 입력은 `C-a C-k`로 지웁니다. `C-u`로 입력을 비우는 기존 동작은 제거했습니다.

검색 중 `RET`로 검색을 적용하고 탐색으로 돌아갑니다. `C-g`로 검색을 해제할 수 있습니다. 검색은 이름 부분 일치 필터이며 Emacs의 본문 증분 검색과는 다릅니다. 파일 보기에서는 `C-g`, `C-x k`, `q` 또는 Esc로 돌아갑니다. 검색·경로 입력에서도 Esc로 취소할 수 있습니다. 방향키와 Home/End는 대응하는 이동 키의 별칭입니다. Meta 입력은 Vty의 Meta와 Alt 이벤트를 모두 처리합니다.

설정 파일 `~/.config/hfm/keybindings.yaml`은 계속 읽지만 모든 스타일 값은 Emacs로 통일됩니다. 기존 `binding_style: vim`/`vi` 설정에서도 Emacs 키가 동작합니다. 탐색 화면의 Vim `j/k/h/l`, `/` 검색, `Tab` 패널 전환, `.` 숨김 전환, `q` 종료, Backspace 상위 이동은 제거했습니다.

복사와 이동은 기존 파일을 덮어쓰지 않으며, 디렉터리를 자기 내부로 복사하거나 이동하지 않습니다. 심볼릭 링크는 링크 자체를 복사하고, 삭제할 때도 링크 자체를 지웁니다. 이동은 같은 파일 시스템 내에서 지원합니다.

## 편집과 명령 실행

`e`는 `VISUAL`, `EDITOR` 순으로 설정된 편집기를 실행합니다. 두 변수가 없으면 Windows에서는 `notepad.exe`, Linux/macOS에서는 `vi`를 사용합니다. 변수에는 인자 없이 실행 파일 이름 또는 전체 경로를 넣습니다. 공백·한글이 들어간 파일 경로도 하나의 인자로 전달합니다. 편집기에서 저장하고 종료하면 두 패널을 새로고칩니다. 파일 보기의 64 KiB 제한은 편집에 적용되지 않습니다. 디렉터리 편집은 `r` 또는 `e`로 이름을 변경하고, `RET`로 열어 내부 파일을 편집하는 방식입니다.

`!` 또는 `M-!`로 명령을 입력하고 `RET`로 실행합니다. Windows는 PowerShell(`powershell.exe -NoProfile`), Linux/macOS는 `/bin/sh`를 사용합니다. 실행 위치는 활성 패널 디렉터리이며 표준 입력·출력·오류를 터미널에서 직접 사용합니다. 명령이 끝나면 출력 확인 후 Enter로 파일 관리자로 돌아갑니다. 편집기와 명령의 종료 코드를 상태줄에 표시하며, 복귀 시 양쪽 파일 목록을 새로고칩니다. `C-g` 또는 Esc로 실행 전 입력을 취소할 수 있습니다. 명령마다 새 셸을 실행하므로 `cd`와 환경 변수 변경은 다음 명령이나 패널에 유지되지 않습니다.

삭제는 확인 후 하위 디렉터리와 파일까지 삭제하며 휴지통으로 이동하지 않습니다. 직접 입력한 셸 명령에는 파일 관리자의 덮어쓰기 방지 정책이 적용되지 않습니다.

## 메뉴 언어 전환

기본 메뉴 언어는 한국어입니다. `F2`를 누르면 한국어 ↔ 영어로 즉시 전환하며, 상단에 현재 언어와 전환 키를 표시합니다. 탐색, 검색, 복사·이동·폴더 생성 입력, 삭제 확인, 파일 보기와 `C-x` 접두 명령 대기 중에도 사용할 수 있습니다.

메뉴, 단축키 안내, 상태 메시지가 함께 전환됩니다. 검색어와 입력 경로, 파일명, 파일 내용, 선택 항목은 유지됩니다. 언어 선택은 현재 실행 중에만 유지되며 다시 실행하면 한국어로 시작합니다. macOS에서 F2가 시스템 기능 키로 설정되어 있다면 `fn+F2`를 사용하세요.

## 테마 선택

`F3`로 테마 메뉴를 엽니다. `↑`/`↓` 또는 `C-p`/`C-n`으로 이동하거나 `1`~`8`으로 선택하면 화면 색상을 즉시 미리 볼 수 있습니다. `RET`로 적용하고, Esc·`C-g`·`F3`로 취소하면 기존 테마로 돌아갑니다. 메뉴의 `*`는 적용된 테마이며, 선택한 항목은 색상으로 강조합니다.

지원 테마는 **Light, Dark, Monokai, Solarized Light, Solarized Dark, Tomorrow Night Blue, Gruvbox Dark, Gruvbox Light**입니다. Gruvbox Dark는 `7`, Gruvbox Light는 `8`로 선택합니다. 기본값은 Dark이며 선택은 현재 실행 중에 유지됩니다. 파일 목록·선택 강조·입력줄·상태줄·파일 보기·테마 메뉴에 같은 팔레트를 적용합니다. 검색, 파일 작업 입력, 삭제 확인과 파일 보기 중에도 열 수 있으며 기존 입력과 선택을 보존합니다. 테마 메뉴 안에서도 `F2`로 언어를 바꾸고 `C-x C-c`로 종료할 수 있습니다. macOS 시스템 기능 키 설정에 따라 `fn+F3`를 사용하세요.

색상은 [VS Code 기본 테마 소스](https://github.com/microsoft/vscode/tree/main/extensions)와 [Gruvbox 원본 팔레트](https://github.com/morhetz/gruvbox/blob/master/colors/gruvbox.vim)를 바탕으로 터미널 UI에 맞춰 구성했습니다. Light/Dark는 Visual Studio 기본 테마 기준이며, Gruvbox는 기본 대비(medium) 기준입니다. RGB를 사용하며, 256색 터미널에서는 Vty가 지원 색상으로 변환합니다. VS Code의 투명도 색상은 터미널에서 표시 가능한 불투명 색상으로 바꿨습니다.

## 배포 스크립트

`./scripts/release.sh deb` 또는 `./scripts/release.sh rpm`으로 Linux 패키지를 만듭니다. `auto`는 Linux에서 두 패키지를 모두 만들고 macOS에서는 DMG를 만듭니다. 생성물은 `dist/release/`에 저장하며 `./scripts/release.sh clean`으로 지울 수 있습니다.

Windows에서는 [NSIS 3](https://nsis.sourceforge.io/Download)을 설치하고 PowerShell 스크립트를 사용합니다. `makensis.exe`는 PATH 또는 NSIS의 기본 설치 위치에서 찾습니다.

```powershell
.\scripts\release.ps1              # auto: NSIS 설치 파일 생성
.\scripts\release.ps1 nsis
.\scripts\release.ps1 clean        # dist/release와 dist/build-bin 삭제
```

`apps/hfm/package.yaml`의 버전으로 `dist/release/hfm-0.1.0.0-windows-setup.exe`를 만듭니다. 설치 파일은 현재 사용자의 `%LOCALAPPDATA%\Programs\hfm`에 `hfm.exe`, README와 LICENSE를 설치하고 시작 메뉴 및 앱 제거 항목을 등록합니다. 관리자 권한이나 PATH 변경은 필요하지 않습니다. PowerShell 스크립트는 `.sh` 파일을 호출하지 않으며, Linux/macOS 패키지는 해당 OS에서 `release.sh`로 만듭니다.

## 개발

```bash
stack test
python3 scripts/check-architecture.py
python3 scripts/test-architecture.py
python3 scripts/test-keybindings.py
```

PowerShell 스크립트의 독립 회귀 검사는 `pwsh -NoProfile -File scripts/test-powershell.ps1`로 실행합니다. 실제 빌드 도구를 대체한 임시 프로젝트에서 한글·공백 경로, 명령 순서, 종료 코드, NSIS 호출과 정리 범위를 검사합니다. `test-keybindings.py`는 Unix PTY 테스트이므로 Windows에서 직접 실행하지 않습니다.

macOS 빌드는 `scripts/link-macos.sh`를 통해 GHC 런타임의 중복 링커 옵션(`-U`와 `dynamic_lookup`, 반복된 `-lm`)을 정리합니다. 다른 링커 진단은 그대로 전달합니다.

## 워크스페이스 구조

순수 모델과 정책, 유스케이스, 부수효과 어댑터, TUI를 독립 Haskell 패키지로 나눈 모노레포입니다. `stack.yaml`과 `cabal.project`에서 전체 패키지를 관리합니다.

```text
apps/hfm/                     # 실행 파일과 의존성 조립
packages/hfm-domain/          # 순수 타입·선택·입력 편집·정책
packages/hfm-application/     # 상태·유스케이스·파일 시스템 포트
packages/hfm-infrastructure/  # 파일 시스템·설정의 실제 IO 구현
packages/hfm-tui/             # Brick/Vty·렌더링·한국어/영어 표시
```

내부 계층은 Brick/Vty와 실제 I/O에 의존하지 않습니다. application의 `planInput`·`planStartup`은 순수한 `Program` 실행 계획을 만들고, `runProgram`이 주입받은 `FileSystem m` 포트로 이를 실행합니다. `Main`에서 실제 IO 구현을 연결하며, 테스트에서는 실행 계획을 직접 검사하거나 메모리 구현으로 실행합니다. 경로 검증·대상 이름 계산은 domain, 상태 메시지의 한국어/영어 표시는 tui가 담당합니다. 의존성 방향과 순수 코드·부수효과 경계, 계층별 테스트·확장 방법은 [아키텍처 문서](docs/ARCHITECTURE.md)에 설명되어 있습니다. 기존 평면 모듈 이름은 `Hfm.*` 네임스페이스로 변경되었습니다.

각 패키지의 `package.yaml`이 빌드 설정의 원본입니다. 수정 후 `stack build`로 `.cabal`을 갱신합니다. `stack test hfm-domain` 또는 `stack test hfm-application`처럼 특정 패키지만 테스트할 수도 있습니다.
