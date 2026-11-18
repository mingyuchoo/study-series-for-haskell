# 릴리스 만들기

macOS/Linux의 진입점은 `scripts/release.sh`, Windows 11의 진입점은 `scripts/release.ps1`입니다. 두 스크립트가 Python 표준 라이브러리로 작성한 공통 파이프라인을 실행합니다. 자동 설치, 다운로드, 업로드는 수행하지 않습니다.

## 준비

모든 OS에서 GHC 9.10 이상, cabal 3.16 이상, Python 3.11 이상, fourmolu, HLint, Bash가 PATH에 있어야 합니다. 최초 빌드 전 `cabal update`로 패키지 인덱스를 준비합니다. Cabal 의존성 다운로드에는 네트워크가 필요할 수 있습니다.

| OS | 추가 필수 도구 | 결과 |
|---|---|---|
| Linux (glibc) | ldd, getconf, dpkg-deb 1.19 이상, rpmbuild | `.tar.gz`, `.deb`, `.rpm` |
| macOS | Xcode Command Line Tools의 pkgbuild, codesign; dylibbundler | `.tar.gz`, `.pkg` |
| Windows 11 | Git for Windows의 Bash, GNU objdump, Inno Setup 6의 ISCC.exe | `.zip`, `-setup.exe` |

예를 들어 Debian/Ubuntu에서는 `dpkg-dev`, `rpm`, `libc-bin` 패키지가 Linux 패키징 도구를 제공합니다. macOS에서는 `xcode-select --install`과 `brew install dylibbundler`로 추가 도구를 준비할 수 있습니다. 네이티브 C 의존성의 헤더와 링커도 GHC/Cabal 빌드 환경에 필요합니다.

Windows에서는 Git의 `bin` 디렉터리와 Inno Setup 설치 디렉터리를 PATH에 추가합니다. GHCup의 MSYS2/binutils가 제공하는 `objdump`도 PATH에서 실행 가능해야 합니다. WSL의 Bash는 사용할 수 없습니다. 기존 저장소 검사는 Git Bash로 실행하며 검사에 필요한 `python3`는 현재 Python 인터프리터로 연결합니다. PowerShell 5.1 이상에서 실행할 수 있습니다.

`.gitattributes`는 Bash 스크립트와 생성 문서를 LF로 유지하며 문서 생성기도 LF를 명시합니다. 이전 Windows 체크아웃에 CRLF 스크립트가 남아 있다면 로컬 변경을 보관한 뒤 이 속성이 적용된 새 체크아웃을 사용합니다.

GHC가 보고하는 대상 OS/아키텍처와 호스트가 일치해야 합니다. x64와 arm64 네이티브 빌드를 지원하며 크로스 컴파일과 universal binary 생성은 하지 않습니다. Windows ARM64는 ARM64 GHC, objdump, ARM64 설치를 지원하는 Inno Setup 도구를 준비한 환경에서 실행해야 합니다.

## 실행

macOS/Linux:

```bash
./scripts/release.sh --check
./scripts/release.sh
./scripts/release.sh --format check --output '/tmp/todo release'
./scripts/release.sh --help
```

Windows 11:

```powershell
.\scripts\release.ps1 -Check
.\scripts\release.ps1
.\scripts\release.ps1 -Format check -OutputDirectory 'C:\releases\todo release'
.\scripts\release.ps1 -Help
```

기본 동작은 **소스에 포맷팅을 적용**합니다. 소스 수정 없이 검사하려면 `--format check` 또는 `-Format check`를 사용합니다. `--check`와 `-Check`는 버전, 네이티브 컴파일러와 필수 도구 존재만 확인하며 빌드/테스트/도구의 실제 패키징 호환성 검증은 하지 않습니다.

스크립트를 실행한 디렉터리와 무관하게 프로젝트 루트를 기준으로 빌드합니다. 상대 출력 경로는 호출자의 작업 디렉터리를 기준으로 해석합니다. 출력 디렉터리가 이미 있으면 덮어쓰지 않고 실패하므로 새 경로를 지정하거나 이전 결과를 별도로 옮깁니다.

## 파이프라인과 산출물

1. 다섯 Cabal 패키지의 숫자 버전이 같은지 확인하고 필수 도구를 검사합니다.
2. 전체 Haskell 소스에 fourmolu를 적용하거나 형식을 검사합니다.
3. 기존 린트, 아키텍처, 컨텍스트 검사를 실행합니다. 린트는 HLint와 `-Werror` 빌드를 포함합니다.
4. Haskell 공유 라이브러리와 동적 실행파일 링크를 비활성화하여 전체 패키지를 빌드합니다.
5. 같은 빌드 옵션으로 전체 Cabal 테스트를 실행합니다.
6. 세 실행 파일과 비시스템 런타임 라이브러리를 모읍니다. 임시 DB에서 CLI로 할 일을 추가하고 API와 웹이 같은 내용을 반환하는지 확인합니다.
7. 압축 번들, 네이티브 설치파일, `SHA256SUMS`를 만듭니다. 모든 단계가 성공해야 출력 디렉터리에 결과를 게시합니다.

Linux arm64의 기본 출력 예시는 `dist/release/0.1.0.0/linux-arm64`입니다.

```text
todo-0.1.0.0-linux-arm64.tar.gz
todo-0.1.0.0-linux-arm64.deb
todo-0.1.0.0-linux-arm64.rpm
SHA256SUMS
```

공개 명령은 `todo`, `todo-api`, `todo-web`입니다. Windows는 각각 `.exe`가 붙습니다. 압축 번들을 풀면 `bin` 아래에서 실행합니다. HTML과 SQLite 스키마는 이미 Haskell 실행 파일에 포함되어 있으므로 사용자 DB나 소스 디렉터리를 배포하지 않습니다.

빌드 실패 시 소스에 적용한 포맷팅과 Cabal 캐시는 남을 수 있습니다. 임시 패키징 파일은 정리되고 기존 출력은 보존됩니다. 번들 실행 검사는 임시 DB만 사용하며 설치나 제거 과정에서 사용자 DB를 생성하거나 삭제하지 않습니다.

## 설치와 실행

Debian/Ubuntu에서는 `sudo apt install ./todo-0.1.0.0-linux-arm64.deb`, RPM 계열에서는 `sudo dnf install ./todo-0.1.0.0-linux-arm64.rpm`처럼 해당 파일을 설치합니다. 패키지 이름은 `haskell-todo`이며 명령은 `/usr/bin`, 앱과 전용 라이브러리는 `/usr/lib/haskell-todo`에 설치됩니다.

macOS `.pkg`는 명령을 `/usr/local/bin`, 앱을 `/usr/local/lib/haskell-todo`에 설치합니다. 제거하려면 실행 중인 서버를 종료한 뒤 이 세 명령과 앱 디렉터리를 제거합니다. pkg 영수증 정리가 필요하면 `pkgutil --forget io.github.mingyuchoo.haskell-todo`를 사용합니다.

Windows 설치파일은 현재 사용자의 `%LOCALAPPDATA%\Programs\HaskellTodo`에 설치하고 시작 메뉴에 Todo Command Prompt, Todo Web, Todo API를 등록합니다. 시스템 PATH는 수정하지 않습니다. Todo Command Prompt에서만 PATH를 추가하며 시작 메뉴의 세 표면은 `%LOCALAPPDATA%\Todo`를 작업 디렉터리로 사용합니다. 제거 프로그램은 이 사용자 데이터 디렉터리를 보존합니다.

Unix에서는 쓰기 가능한 작업 디렉터리에서 실행하거나 `TODO_DB`에 절대 경로를 지정합니다. 세 표면이 같은 DB를 사용하려면 같은 `TODO_DB` 값을 사용합니다. CLI는 `todo --help`, 웹은 `todo-web` 실행 후 `http://127.0.0.1:8081`, API는 `todo-api` 실행 후 `http://127.0.0.1:8080/todos`로 접근합니다. 포트는 기존 `TODO_WEB_PORT`, `TODO_API_PORT`로 설정합니다. 서버는 기존처럼 루프백에만 바인딩합니다.

## 호환성과 배포 전 확인

Linux 번들은 glibc와 로더를 제외한 링크된 공유 라이브러리를 포함합니다. `.deb`와 `.rpm`은 빌드 머신의 glibc 버전 이상을 요구합니다. 오래된 배포판을 지원하려면 지원 대상 중 가장 오래된 glibc 환경에서 빌드합니다. Alpine/musl은 지원하지 않습니다.

macOS 번들은 dylibbundler로 외부 dylib 경로를 수정하고 ad-hoc 서명을 적용합니다. 실행 가능한 최소 macOS 버전은 GHC와 의존 라이브러리의 빌드 대상에 따릅니다. Windows는 import table을 재귀적으로 검사하여 비시스템 DLL을 실행 파일 옆에 모읍니다. 번들에 포함되는 외부 라이브러리의 라이선스와 고지 의무는 배포자가 확인해야 합니다.

생성 설치파일에는 Developer ID 서명, notarization, Authenticode 서명을 적용하지 않습니다. 공개 배포가 필요하면 조직의 인증서로 서명한 뒤 체크섬을 다시 생성합니다. 이 파이프라인은 개발자 인증서를 추측하거나 자동으로 사용하지 않습니다.

각 OS/아키텍처에서 압축 번들을 새 디렉터리에 풀어 실행하고, 설치파일 설치/실행/제거와 DB 보존을 확인합니다. 네이티브 도구가 없는 OS의 실제 설치를 다른 OS에서 검증할 수는 없습니다.

릴리스 도구 자체의 회귀 테스트는 다음과 같이 실행하며 기존 `scripts/quality/test.sh`에도 포함됩니다.

```bash
PYTHONPATH=scripts/release python3 -m unittest discover -s scripts/release/tests -v
```

도구 동작의 원문은 [Cabal 명령 문서](https://cabal.readthedocs.io/en/stable/cabal-commands.html), [dylibbundler](https://github.com/auriamg/macdylibbundler), [RPM spec 문서](https://rpm.org/docs/4.20.x/manual/spec.html), [Inno Setup 문서](https://jrsoftware.org/ishelp/)를 참고합니다.
