# Plan: Native release pipeline

- 상태: Completed
- 작성일: 2026-11-19
- 소유자: 저장소 유지보수자
- 위험 수준: Level 2
- 관련 ADR: ADR-0002, ADR-0004

## Objective

`scripts/release.sh`와 `scripts/release.ps1`에서 포맷팅, 린트, 빌드, 전체 테스트, 번들링, 설치파일 생성을 순서대로 수행한다.

## Design and Approaches

각 운영체제에서 네이티브 빌드한다. 공통 Python 표준 라이브러리 파이프라인을 Bash와 PowerShell에서 호출하여 품질 게이트와 메타데이터의 중복을 피한다. OS별 패키징은 어댑터로 분리한다. macOS는 pkgbuild와 dylibbundler, Linux는 dpkg-deb와 rpmbuild, Windows 11은 Inno Setup과 objdump를 사용한다. Windows의 기존 저장소 검사는 Git Bash로 실행한다.

독립 Bash/PowerShell 구현은 품질 게이트와 버전 판독을 중복하므로 선택하지 않았다. 컨테이너를 통한 크로스 빌드는 macOS와 Windows의 네이티브 설치 도구를 대체하지 못하므로 선택하지 않았다. 이 도구 선택은 구현자의 판단이다.

## Context Retrieved

- `ARCHITECTURE.md`, `docs/ai/WORKFLOW.md`, `docs/ai/IMPACT_ANALYSIS.md`, `docs/ai/DEFINITION_OF_DONE.md`
- `docs/decisions/ADR-0002-effect-boundary.md`, `docs/decisions/ADR-0004-web-surface.md`
- `docs/contracts/data/TODO-STORE-v1.md`, `docs/incidents/INC-2026-001.md`, `docs/tech-debt/active.md`
- 기존 run, quality, context 스크립트와 다섯 cabal 파일

## Impact Analysis

- Domain/API/Data/Events: 규칙, 계약, 스키마와 이벤트는 변경하지 않는다. 설치 과정에서 DB를 생성하거나 삭제하지 않는다.
- Code: 릴리스 도구와 테스트를 추가한다. 실제 실행에서 발견한 기존 HLint 지적 10건은 api 테스트와 web의 동작을 유지하는 표현 정리로 해소한다. Haskell 패키지 간 의존 방향은 유지한다.
- CLI: 기존 실행 파일의 외부 배포 이름은 todo, todo-api, todo-web이다. 앱 인자와 출력은 유지한다.
- Security: 서버의 루프백 바인딩은 유지한다. 외부 명령은 인자 배열로 실행한다. 자동 다운로드, 설치, 배포는 하지 않는다.
- Operations: 필수 도구 누락과 단계 실패는 즉시 비정상 종료한다. 기존 출력 디렉터리는 덮어쓰지 않는다. 임시 디렉터리에서 작업하고 성공한 결과만 게시한다.
- Runtime: Haskell 라이브러리는 정적으로 링크하고 비시스템 공유 라이브러리는 번들에 포함한다. Linux glibc와 macOS 시스템 라이브러리는 OS가 제공한다.
- Windows 호환성: Bash 스크립트와 생성 문서는 LF 속성을 적용하고 Python 연결 파일 및 기존 문서 생성기의 출력에 LF를 명시한다. 생성 문서의 내용은 유지한다.
- Tests: 순수 메타데이터/의존성 파싱, 실패 전파, 공백 경로, 번들 실행, 실제 Linux 패키지 내용과 메타데이터를 검증한다.

## Tasks

- [x] 1. 버전, 플랫폼, 의존성 파싱의 실패 테스트를 작성하고 순수 메타데이터 모듈을 구현한다.
- [x] 2. 공통 파이프라인, OS별 번들/설치 어댑터, Bash/PowerShell 진입점을 구현하고 실패 게이트와 출력 보호를 검증한다.
- [x] 3. 사용법과 필수 도구를 문서화하고 실제 Linux 릴리스 및 저장소 필수 검사를 실행한다.

## Review Focus

- 도구 누락/검증 실패 후 설치파일이 생성되지 않아야 한다.
- 호스트와 다른 컴파일러 아키텍처 또는 잘못된 버전은 거부해야 한다.
- 공백이 포함된 출력 경로를 지원하고 기존 파일을 보존해야 한다.
- 개발 환경 밖에서 공유 라이브러리를 찾고 사용자 작업 디렉터리를 보존해야 한다.
- macOS/Windows 실제 실행이 불가능한 경우 그 검증 한계를 기록해야 한다.

## Verification

Python unittest, Bash 문법 검사, 가능하면 PowerShell 파서, Linux 실제 deb/rpm 생성 및 추출 실행을 수행한다. 저장소의 lint, test, architecture-check, validate-context를 실행한다. 생성 문서 원본은 변경하지 않으므로 재생성하지 않는다.

## Rollout and Rollback

네이티브 OS에서 스크립트를 실행한 뒤 생성된 압축 파일, 설치파일, 체크섬을 검토한다. 설치와 배포는 스크립트가 수행하지 않는다. 되돌리려면 새 릴리스 도구와 문서 변경을 제거한다. 사용자 DB에 영향이 없다.

## Context Consolidation

릴리스 운영 문서를 README와 연결하고 테스트 실행 위치를 테스트 지도에 등록한다. 완료 시 계획을 completed로 이동하고 실제 검증 결과와 잔여 위험을 기록한다.

## Result

- Linux ARM64에서 전체 릴리스 파이프라인을 실행하여 압축 번들, deb, rpm과 SHA256SUMS를 생성했다. 체크섬, 패키지 버전/아키텍처/의존성과 포함 파일을 확인했다.
- 압축 번들과 deb 내용물을 공백이 있는 별도 임시 경로에 풀고 CLI 쓰기, API/웹 조회를 검증했다. 시스템 설치는 수행하지 않았다.
- Haskell 다섯 테스트 스위트의 204 examples와 릴리스 도구 테스트 17개가 통과했다. 린트, 무경고 빌드, 아키텍처, 컨텍스트 검사가 통과했다.
- 기존 HLint 지적 10건을 동작 변경 없이 정리했다. 별도 코드 검토에서 발견한 Windows 연결 파일 및 문서 생성기의 CRLF 문제는 Windows 기본 줄바꿈을 모사한 실패 테스트 후 LF 출력으로 수정했다. Git 속성도 LF를 강제한다.
- 문서 생성기 네 개를 재실행했고 기존 생성 문서와 바이트 단위 결과가 같음을 확인했다.
- macOS/Windows 네이티브 빌드와 설치/제거는 해당 환경이 없어 실행하지 못했다. 각 환경에서 설치 도구, 외부 dylib/DLL, 코드 서명 정책을 확인하는 배포 전 검증이 남는다. 설치파일 서명과 공증은 자동화 범위에 포함하지 않는다.
