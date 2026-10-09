# fzh

[![CI](https://github.com/mingyuchoo/fzh/workflows/CI/badge.svg)](https://github.com/mingyuchoo/fzh/actions)
[![Release](https://github.com/mingyuchoo/fzh/workflows/Release/badge.svg)](https://github.com/mingyuchoo/fzh/releases)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

> Haskell로 작성된 퍼지 파인더 TUI 애플리케이션

`fzh`는 [Brick](https://github.com/jtdaugherty/brick) 라이브러리 기반의 터미널 퍼지 파인더입니다. fzf와 유사한 기능을 제공하며 Emacs/Vim 스타일 키바인딩을 지원합니다.

## 주요 기능

- 🔍 **퍼지 검색**: 빠르고 직관적인 파일 검색
- ⌨️  **키바인딩**: Emacs/Vim 스타일 선택 가능
- 🎨 **실시간 미리보기**: 선택한 파일의 내용을 즉시 확인
- 🌈 **구문 강조**: 200개 이상의 프로그래밍 언어 지원
- 📐 **동적 레이아웃**: 터미널 전체 크기에 맞춰 자동 조정 (최소 80x24)
- 🚀 **성능 최적화**: 불필요한 디렉토리 자동 제외 (.git, node_modules 등)
- 📦 **파이프 지원**: stdin으로 목록을 받거나 파일 시스템 탐색

## 요구사항

- **운영체제**: Linux 또는 macOS (Windows에서는 WSL 사용)
- **컴파일러**: GHC 9.14.1 (`base` 4.22.0.0)
- **빌드 도구**: Stack 3.11.1 이상
- **최소 터미널 크기**: 80x24
- 더 작은 크기에서는 경고 메시지가 표시되나 계속 사용 가능
- 최적의 사용을 위해 100x30 이상 권장

의존성은 [Stackage Nightly 2026-10-09](https://www.stackage.org/nightly-2026-10-09)를
기준으로 하며, 직접 의존성은 2026-10-10에 확인한 Hackage 최신 호환 릴리스를 사용합니다.
스냅샷보다 최신인 패키지는 `stack.yaml`의 `extra-deps`에 지정하고,
`stack.yaml.lock`으로 정확한 패키지 리비전과 해시를 고정합니다.
주요 라이브러리는 Brick 3.0, Vty 6.6, vty-unix 0.4.0.0, Skylighting 0.15,
Hspec 2.11.18입니다. Nix는 `haskell.compiler.ghc9141`을 제공하는 nixpkgs가 필요합니다.
`time`은 최신 Aeson과 time-compat의 `time < 1.16` 제약으로 1.15를 사용합니다.
간접 의존성의 tagged는 Aeson과 indexed-traversable-instances의 `tagged < 0.9` 제약으로
0.8.11을 사용합니다. 의존성 상한을 강제로 무시하지 않습니다.
Stack 3.11.1의 custom setup 코드가 Cabal 3.18 API와 호환되지 않아,
Cabal과 Cabal-syntax는 3.16.1.0으로 고정합니다.
사용하지 않던 doctest와 doctest-discover 의존성은 제거했습니다.
doctest 0.25.0.2는 GHC 9.14.1에서 컴파일되지 않으며, 실제 테스트는 Hspec으로 실행합니다.

## 설치

### Stack 사용

```bash
# 프로젝트 클론
git clone https://github.com/mingyuchoo/fzh.git
cd fzh

# 빌드
stack build

# 설치 (선택 사항)
stack install
```

### Nix 개발 셸

`default.nix`는 GHC와 개발 도구를 제공하는 셸입니다. 라이브러리는 Stack의
동일한 lock 파일로 관리하여 nixpkgs의 이전 패키지 버전이 선택되는 것을 방지합니다.

```bash
nix-shell --run 'stack build --system-ghc'
nix-shell --run 'stack test --system-ghc'
```

## 사용 방법

### 기본 사용 (파일 시스템 탐색)

```bash
# 현재 디렉토리부터 재귀적으로 파일 검색
stack run
# 또는 설치 후
fzh-exe
```

### 파이프 사용

```bash
# 파일 목록을 파이프로 전달
find . -name "*.hs" | fzh-exe

# git 파일 목록에서 검색
git ls-files | fzh-exe

# 다른 명령과 조합
cat file-list.txt | fzh-exe
```

## 키바인딩

### Emacs 스타일 (기본)

| 키 조합 | 동작 |
|--------|------|
| `Ctrl+p` / `↑` | 위로 이동 |
| `Ctrl+n` / `↓` | 아래로 이동 |
| `Ctrl+g` / `ESC` | 종료 |
| `Ctrl+u` | 검색어 전체 삭제 |
| `Ctrl+h` / `Backspace` | 한 글자 삭제 |
| `Enter` | 선택 및 종료 |

### Vim 스타일

| 키 조합 | 동작 |
|--------|------|
| `Ctrl+k` / `↑` | 위로 이동 |
| `Ctrl+j` / `↓` | 아래로 이동 |
| `Ctrl+c` / `ESC` | 종료 |
| `Ctrl+u` | 검색어 전체 삭제 |
| `Ctrl+w` / `Backspace` | 한 글자 삭제 |
| `Enter` | 선택 및 종료 |

## 설정

키바인딩 스타일을 변경하려면 설정 파일을 생성하세요:

```bash
# 설정 디렉토리 생성
mkdir -p ~/.config/fzh

# 설정 파일 생성
cat > ~/.config/fzh/keybindings.yaml << EOF
binding_style: vim  # 또는 emacs
EOF
```

**설정 파일 위치**: `~/.config/fzh/keybindings.yaml`

**예시** (`config/keybindings.yaml` 참조):

```yaml
# fzh 키바인딩 설정
# binding_style: emacs 또는 vim

binding_style: emacs
```

## 자동 제외되는 디렉토리

성능 향상을 위해 다음 디렉토리들은 자동으로 검색에서 제외됩니다:

- `node_modules`, `dist`, `dist-newstyle`, `build`, `target`
- 모든 숨김 파일/디렉토리 (`.`으로 시작하는 파일 - `.git`, `.stack-work`, `.idea`, `.vscode` 등 포함)

## 개발

### 프로젝트 생성 (템플릿 사용)

```bash
stack new <project-name> mingyuchoo/tui
```

### 빌드

```bash
stack build

# 또는 watch 모드
stack build --fast --file-watch --ghc-options "-j4 +RTS -A128m -n2m -RTS"
```

### 테스트

```bash
# 일반 테스트
stack test

# watch 모드로 테스트
stack test --fast --file-watch --watch-all

# 커버리지 포함
stack test --coverage --fast --file-watch --watch-all --haddock

# ghcid 사용
ghcid --command "stack ghci test/Spec.hs"
```

### 코드 구조

자세한 아키텍처 정보는 [ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참조하세요.

```
fzh/
├── app/Main.hs          # 진입점
├── src/
│   ├── Lib.hs           # 앱 정의
│   ├── Types.hs         # 타입 정의
│   ├── Config.hs        # 설정 관리
│   ├── Event.hs         # 이벤트 처리
│   ├── Fuzzy.hs         # 퍼지 매칭
│   ├── UI.hs            # UI 렌더링
│   ├── Vty.hs           # 터미널 I/O
│   └── FileSearch.hs    # 파일 검색
└── test/Spec.hs         # 단위 테스트
```

## Makefile

편의를 위해 `Makefile`을 제공합니다:

```bash
make build   # 빌드
make test    # 테스트
make run     # 실행
make clean   # 정리
```

## 라이선스

BSD-3-Clause

## 기여

이슈 및 PR을 환영합니다!

## 관련 프로젝트

- [fzf](https://github.com/junegunn/fzf) - Go로 작성된 커맨드라인 퍼지 파인더
- [Brick](https://github.com/jtdaugherty/brick) - Haskell TUI 라이브러리
