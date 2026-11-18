# GeneralService

회원가입·로그인한 구성원이 Task 상태를 등록·수정·삭제하는 Haskell + Elm 웹 서비스입니다.

## 실행

Stack, Fourmolu, HLint, Elm 0.19.3, elm-format, Node.js와 npm을 `PATH`에 준비합니다. Windows에서는 Windows PowerShell 또는 PowerShell에서 실행합니다. 두 스크립트는 프로젝트 루트를 기준으로 소스를 포맷하고, HLint 검사와 Elm 포맷 검증, 빌드, 테스트를 순서대로 수행합니다. Elm 테스트 도구는 `web/package-lock.json`을 기준으로 설치합니다. HLint 경고는 출력한 뒤 계속 진행합니다.

Linux·macOS

```bash
./scripts/run.sh
```

Windows 11

```powershell
.\scripts\run.ps1
```

검증까지만 실행하려면 Bash에서 `--check-only`, PowerShell에서 `-CheckOnly`를 지정합니다. 검증 전용 실행도 소스를 포맷하고 `web/elm.js`를 갱신합니다.

검증을 통과하면 서버를 포그라운드에서 실행합니다. 브라우저에서 `http://localhost:3000`을 엽니다. 다른 포트를 사용하려면 `PORT` 환경 변수를 설정합니다. 포트가 이미 사용 중이면 서버 시작이 실패합니다. 서버를 종료하려면 `Ctrl+C`를 누릅니다.

두 스크립트의 기본 데이터베이스는 프로젝트 루트의 `general-service.sqlite3`입니다. 다른 위치를 사용하려면 실행 환경에 `DATABASE_PATH`를 지정합니다. `.env.example`은 설정 예시일 뿐 애플리케이션이 `.env` 파일을 자동으로 읽지는 않습니다.

```bash
DATABASE_PATH=/absolute/path/general-service.sqlite3 stack run
```

빈 `DATABASE_PATH`는 허용되지 않습니다. 서버 시작 시 스키마 전진 마이그레이션을 트랜잭션으로 적용하며, 서버보다 새로운 스키마 버전이면 시작을 거부합니다.

예시 Task 시드는 기본적으로 활성화됩니다. 개발 환경이 아니거나 빈 DB를 빈 상태로 시작해야 하면 리터럴 소문자 `false`를 지정합니다.

```bash
DATABASE_PATH=/absolute/path/general-service.sqlite3 SEED_EXAMPLE_DATA=false stack run
```

## 기능

- 이메일·비밀번호·표시 이름으로 회원가입 및 로그인
- 로그인한 사용자의 표시 이름을 수정하는 내 프로필 관리와 로그아웃
- 업무 제목, 설명, 상태의 생성·조회·수정·삭제
- `Draft`, `Reviewed`, `Submitted`, `Approved`, `Effective` 상태를 한국어로 표시
- 긴급도·중요도 조합으로 계산한 아이젠하워 매트릭스 실행 분류(즉시 실행, 계획 수립, 위임, 제거)별 Task 목록 표시
- 실행 분류와 별개로 상태별 스윔레인(초안, 검토 완료, 제출됨, 승인됨, 효력 발생)에서 진행 상태를 관리하고 드래그 앤 드롭으로 상태 변경
- 실행 분류와 상태 스윔레인의 카드는 제목, Task Owner, 실행 분류, 진행 상태, 결과물 진행 상태, 설명 요약을 표시하며, 카드를 누르면 전체 내용을 담은 상세 패널이 열림
- 상세 패널은 실행 분류와 진행 상태를 각각 명확히 표시해 두 축을 혼동하지 않음
- 상세 패널에서 수정, 삭제와 함께 Task Owner의 결과물 제출, Outcome Owner의 승인과 수정 요청을 처리
- 신규 업무는 상태 선택 없이 항상 `초안`으로 등록
- 긴급도·중요도는 라디오 버튼으로 즉시 선택
- 작업 결과를 알려주는 3초 자동 소멸 토스트 알림
- 깊은 그린, 크림, 카드형 정보 구조의 따뜻한 카페 스타일 관리자 UI

## API

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| `GET` | `/api/task` | 업무 전체 조회 |
| `POST` | `/api/task` | 업무 생성 |
| `PUT` | `/api/task/:id` | 업무 수정 |
| `DELETE` | `/api/task/:id` | 업무 삭제 |
| `POST` | `/api/task/:id/submit` | Task Owner가 결과물 제출 (`taskOwner`, `submittedResult`) |
| `POST` | `/api/task/:id/approve` | Outcome Owner가 결과물 승인 (`outcomeOwner`, 선택 `reviewComment`) |
| `POST` | `/api/task/:id/revision` | Outcome Owner가 수정 요청 (`outcomeOwner`, 선택 `reviewComment`) |
| `GET` | `/api/outcome` | Outcome 전체 조회 |
| `POST` | `/api/outcome` | 승인된 업무를 묶어 Outcome 생성 |
| `POST` | `/api/auth/signup` | 회원가입 (`email`, `displayName`, `password`) |
| `POST` | `/api/auth/login` | 로그인 (`email`, `password`) |
| `POST` | `/api/auth/logout` | 로그아웃 (Bearer 토큰) |
| `GET` | `/api/auth/me` | 내 프로필 조회 (Bearer 토큰) |
| `PUT` | `/api/auth/me` | 내 표시 이름 변경 (`displayName`, Bearer 토큰) |

## 데이터 영속성과 세션

Task, Outcome, 사용자, 세션은 SQLite에 저장되어 정상적인 서버 재시작 뒤에도 유지됩니다. 비밀번호는 bcrypt 해시로만 저장합니다. 로그인 세션은 생성 시점부터 24시간 동안 유효하며, 만료된 세션으로 사용자 정보를 조회하면 해당 세션을 삭제하고 인증을 거부합니다.

`SEED_EXAMPLE_DATA`가 활성화된 경우에만 예시 Task를 새 데이터베이스의 빈 Task 테이블에 한 번 추가하며, 시드 처리 여부를 데이터베이스에 기록합니다. 기존 데이터가 있으면 예시 Task를 추가하지 않습니다. 과거 서버 프로세스에 있던 메모리 데이터는 SQLite로 자동 이관되지 않습니다. 전환 전에 종료된 메모리 데이터의 자동 복구나 가져오기 도구도 제공하지 않습니다.

현재 서버는 하나의 SQLite 연결을 프로세스 안에서 직렬화하고 WAL 모드를 사용합니다. 단일 서버 인스턴스 운영을 전제로 하며, 여러 서버 인스턴스나 공유 파일시스템에서 같은 파일을 사용하는 구성은 지원하지 않습니다.

## 백업과 복원

로컬 백업은 SQLite CLI를 사용할 수 있다면 `.backup` 명령으로 일관된 스냅샷을 만듭니다. 실제 경로와 백업 파일은 실행 전에 확인합니다.

```bash
sqlite3 general-service.sqlite3 ".backup 'general-service-backup.sqlite3'"
sqlite3 general-service-backup.sqlite3 "PRAGMA integrity_check;"
```

복원할 때는 서버를 먼저 정상 종료하고 현재 DB도 별도로 백업한 뒤, 검증된 백업을 명시적인 대상 경로에 복원합니다.

```bash
sqlite3 general-service.sqlite3 ".restore 'general-service-backup.sqlite3'"
sqlite3 general-service.sqlite3 "PRAGMA integrity_check;"
```

실행 중인 DB 파일과 `-wal`·`-shm` 파일을 각각 복사해 백업하지 않습니다. 기존 운영 DB에 마이그레이션 또는 복원을 적용하는 작업은 사전 백업과 복원 리허설을 준비하고 별도의 사람 승인을 받은 뒤 수행해야 합니다. 이 변경은 운영 DB 적용이나 배포를 포함하지 않습니다.

이 구현은 개발·단일 인스턴스 용도입니다. HTTPS, 속도 제한, 감사 로그 및 인증된 사용자에 기반한 Task 권한 검증 없이 외부에 배포하면 안 됩니다.
