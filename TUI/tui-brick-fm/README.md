# fzh 터미널 파일 관리자

Brick으로 만든 두 패널 터미널 파일 관리자입니다. Midnight Commander처럼 좌우 디렉터리를 나란히 보며 탐색하고 파일을 복사하거나 이동할 수 있습니다.

## 실행

```bash
stack build
stack run
stack run -- /path/to/left /path/to/right

# 같은 실행을 scripts에서
./scripts/run.sh run /path/to/left /path/to/right
```

인자가 없으면 양쪽 패널 모두 현재 디렉터리에서 시작합니다. 인자 하나만 주면 왼쪽 패널만 해당 경로에서 시작합니다. 실행에는 대화형 터미널(`/dev/tty`)이 필요합니다.

## 키

| 키 | 동작 |
|---|---|
| `Tab` | 활성 패널 전환 |
| `Ctrl+P`/`Ctrl+N` (`↑`/`↓`), `Ctrl+V`/`Meta+V` (`PgDn`/`PgUp`) | 이전/다음 항목 선택, 페이지 이동 |
| `Enter` | 디렉터리 열기 또는 파일 보기 |
| `Backspace` | 상위 디렉터리 |
| `/` | 현재 패널 이름 검색. `Enter` 적용, `Esc` 해제 |
| `F3` | 파일 보기 (최대 64 KiB, 스크롤 가능) |
| `F5` | 복사. 기본 대상은 반대 패널 디렉터리 |
| `F6` | 이동 또는 이름 변경. 기본 대상은 반대 패널 디렉터리 |
| `F7` | 디렉터리 만들기 |
| `F8` | 선택 항목 삭제 확인 |
| `F9` | 숨김 파일 표시 전환 |
| `Ctrl+R` | 두 패널 새로고침 |
| `Ctrl+G` (`F10`, `q`) | 취소 또는 종료 |

검색과 경로 입력에서는 `Ctrl+A`/`Ctrl+E`로 처음/끝, `Ctrl+B`/`Ctrl+F`로 한 글자씩 커서를 옮깁니다. `Ctrl+H`/`Ctrl+D`는 커서 앞/뒤 글자를, `Ctrl+K`는 커서 뒤를, `Ctrl+W`는 앞 단어를 지우며 `Ctrl+U`는 입력을 비웁니다. 검색 중 `Ctrl+P`/`Ctrl+N`으로 결과를 이동하고 `Ctrl+G`로 취소할 수 있습니다. 파일 보기에서는 `Ctrl+P`/`Ctrl+N`으로 스크롤하고 `Ctrl+V`/`Meta+V`로 페이지를 이동합니다. 복사와 이동은 기존 파일을 덮어쓰지 않으며, 디렉터리를 자기 내부로 복사하거나 이동하지 않습니다. 심볼릭 링크는 링크 자체를 복사하고, 삭제할 때도 링크 자체를 지웁니다. 이동은 같은 파일 시스템 내에서 지원합니다. 파일을 본 뒤에는 `Ctrl+G`, `Esc`, `F3`, `q`로 돌아갑니다.

설정 파일 `~/.config/fzh/keybindings.yaml`에서 `binding_style: vim`을 지정하면 탐색 중 `j`/`k`/`h`/`l`도 사용할 수 있습니다. 기본값은 Emacs 스타일이며 `Ctrl+N`/`Ctrl+P`로 이동할 수 있습니다.

## 배포 스크립트

`./scripts/release.sh deb` 또는 `./scripts/release.sh rpm`으로 Linux 패키지를 만듭니다. `auto`는 Linux에서 두 패키지를 모두 만들고 macOS에서는 DMG를 만듭니다. 생성물은 `dist/release/`에 저장하며 `./scripts/release.sh clean`으로 지울 수 있습니다. PowerShell 래퍼(`scripts/run.ps1`, `scripts/release.ps1`)는 Windows에서 WSL로 실행합니다. 현재 프로그램은 `/dev/tty`와 `System.Posix`를 사용하므로 네이티브 Windows MSI는 지원하지 않습니다.

## 개발

```bash
stack test
```

핵심 코드는 `src/FileManager.hs`(파일 시스템 작업), `src/Types.hs`(상태), `src/Event.hs`(키 처리), `src/UI.hs`(화면)에 있습니다.
