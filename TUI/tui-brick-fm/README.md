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

인자가 없으면 양쪽 패널 모두 현재 디렉터리에서 시작합니다. 인자 하나만 주면 왼쪽 패널만 해당 경로에서 시작합니다. 실행에는 대화형 터미널(`/dev/tty`)이 필요합니다.

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
| `C` | 복사. 기본 대상은 반대 패널 디렉터리 |
| `R` | 이동 또는 이름 변경. 기본 대상은 반대 패널 디렉터리 |
| `+` | 디렉터리 만들기 |
| `D` | 선택 항목 삭제 확인. `y`/`Y`로 실행, 다른 키로 취소 |
| `M-o` | 숨김 파일 표시 전환 (hfm 확장 명령) |
| `g` | 두 패널 새로고침 |
| `C-x C-c` | 모든 화면에서 종료 |
| `C-g` | 검색 해제, 입력·삭제 취소, 파일 보기 닫기, 접두 명령 취소 |
| `C-x k` | 현재 검색·입력·보기 닫기 |

검색과 경로 입력에서는 `C-a`/`C-e`로 처음/끝, `C-b`/`C-f`로 한 글자, `M-b`/`M-f`로 한 단어씩 커서를 옮깁니다. `C-h`/Backspace와 `C-d`/Delete는 커서 앞/뒤 글자를 지우고, `C-k`는 커서부터 끝까지 지웁니다. `M-Backspace`와 `M-d`는 앞/뒤 단어를 지웁니다. 기존 `C-w`도 앞 단어 삭제의 별칭으로 사용할 수 있습니다. 전체 입력은 `C-a C-k`로 지웁니다. `C-u`로 입력을 비우는 기존 동작은 제거했습니다.

검색 중 `RET`로 검색을 적용하고 탐색으로 돌아갑니다. `C-g`로 검색을 해제할 수 있습니다. 검색은 이름 부분 일치 필터이며 Emacs의 본문 증분 검색과는 다릅니다. 파일 보기에서는 `C-g`, `C-x k`, `q` 또는 Esc로 돌아갑니다. 검색·경로 입력에서도 Esc로 취소할 수 있습니다. 방향키와 Home/End는 대응하는 이동 키의 별칭입니다. Meta 입력은 Vty의 Meta와 Alt 이벤트를 모두 처리합니다.

설정 파일 `~/.config/hfm/keybindings.yaml`은 계속 읽지만 모든 스타일 값은 Emacs로 통일됩니다. 기존 `binding_style: vim`/`vi` 설정에서도 Emacs 키가 동작합니다. 탐색 화면의 Vim `j/k/h/l`, `/` 검색, `Tab` 패널 전환, `.` 숨김 전환, `q` 종료, Backspace 상위 이동은 제거했습니다.

복사와 이동은 기존 파일을 덮어쓰지 않으며, 디렉터리를 자기 내부로 복사하거나 이동하지 않습니다. 심볼릭 링크는 링크 자체를 복사하고, 삭제할 때도 링크 자체를 지웁니다. 이동은 같은 파일 시스템 내에서 지원합니다.

## 메뉴 언어 전환

기본 메뉴 언어는 한국어입니다. `F2`를 누르면 한국어 ↔ 영어로 즉시 전환하며, 상단에 현재 언어와 전환 키를 표시합니다. 탐색, 검색, 복사·이동·폴더 생성 입력, 삭제 확인, 파일 보기와 `C-x` 접두 명령 대기 중에도 사용할 수 있습니다.

메뉴, 단축키 안내, 상태 메시지가 함께 전환됩니다. 검색어와 입력 경로, 파일명, 파일 내용, 선택 항목은 유지됩니다. 언어 선택은 현재 실행 중에만 유지되며 다시 실행하면 한국어로 시작합니다. macOS에서 F2가 시스템 기능 키로 설정되어 있다면 `fn+F2`를 사용하세요.

## 배포 스크립트

`./scripts/release.sh deb` 또는 `./scripts/release.sh rpm`으로 Linux 패키지를 만듭니다. `auto`는 Linux에서 두 패키지를 모두 만들고 macOS에서는 DMG를 만듭니다. 생성물은 `dist/release/`에 저장하며 `./scripts/release.sh clean`으로 지울 수 있습니다. PowerShell 래퍼(`scripts/run.ps1`, `scripts/release.ps1`)는 Windows에서 WSL로 실행합니다. 현재 프로그램은 `/dev/tty`와 `System.Posix`를 사용하므로 네이티브 Windows MSI는 지원하지 않습니다.

## 개발

```bash
stack test
python3 scripts/check-architecture.py
python3 scripts/test-keybindings.py
```

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

내부 계층은 Brick/Vty와 실제 I/O에 의존하지 않습니다. application이 정의한 `FileSystem m` 포트를 `Main`에서 실제 구현과 연결하며, 테스트에서는 메모리 구현으로 교체합니다. 의존성 방향과 순수 코드·부수효과 경계, 계층별 테스트·확장 방법은 [아키텍처 문서](docs/ARCHITECTURE.md)에 설명되어 있습니다. 기존 평면 모듈 이름은 `Hfm.*` 네임스페이스로 변경되었습니다.

각 패키지의 `package.yaml`이 빌드 설정의 원본입니다. 수정 후 `stack build`로 `.cabal`을 갱신합니다. `stack test hfm-domain` 또는 `stack test hfm-application`처럼 특정 패키지만 테스트할 수도 있습니다.
