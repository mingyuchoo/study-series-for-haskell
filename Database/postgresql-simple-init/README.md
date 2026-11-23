# postgresql-simple-init

PostgreSQL과 Haskell을 사용한 헥사고날 아키텍처(Hexagonal Architecture) 기반 웹 애플리케이션 예제입니다.

## 📋 개요

이 프로젝트는 다음을 보여줍니다:

- **헥사고날 아키텍처(포트 & 어댑터)** 패턴 구현
- **postgresql-simple**을 사용한 PostgreSQL 데이터베이스 연동
- **WAI/Warp**를 사용한 경량 HTTP 서버
- **Docker 멀티스테이지 빌드**를 통한 최적화된 컨테이너 이미지
- **Stack** 빌드 도구를 사용한 Haskell 프로젝트 관리

## 🏗️ 아키텍처

프로젝트는 헥사고날 아키텍처를 따르며 다음과 같은 계층으로 구성됩니다:

```
┌─────────────────────────────────────────┐
│         Infrastructure Layer            │
│  (Postgres.hs - 환경변수, 연결 관리)     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Adapters Layer                 │
│  (PostgresRepository.hs - 구체 구현)    │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        Application Layer                │
│  (UseCases.hs - 비즈니스 로직)          │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Domain Layer                   │
│  (Model.hs, Repository.hs - 인터페이스) │
└─────────────────────────────────────────┘
```

### 디렉터리 구조

```
.
├── app/                    # 애플리케이션 진입점
│   └── Main.hs
├── src/                    # 소스 코드
│   ├── Domain/             # 도메인 계층 (순수 비즈니스 로직)
│   │   ├── Model.hs        # 엔터티 정의
│   │   └── Repository.hs   # 레포지토리 인터페이스 (포트)
│   ├── Application/        # 애플리케이션 계층
│   │   └── UseCases.hs     # 유스케이스 구현
│   ├── Adapters/           # 어댑터 계층
│   │   └── PostgresRepository.hs  # PostgreSQL 구현체
│   ├── Infrastructure/     # 인프라 계층
│   │   └── Postgres.hs     # DB 연결 관리
│   └── Lib.hs              # 애플리케이션 조립 및 HTTP 서버
├── docker/                 # Docker 관련 파일
│   ├── Dockerfile          # 멀티스테이지 빌드
│   └── docker-compose.yaml # 서비스 오케스트레이션
├── test/                   # 테스트 코드
├── static/                 # 정적 파일
├── package.yaml            # 프로젝트 메타데이터
├── stack.yaml              # Stack 설정
└── Makefile                # 빌드 자동화
```

## 🚀 시작하기

### 사전 요구사항

- **Haskell Stack** (>= 2.0)
- **Docker & Docker Compose** (선택사항, 컨테이너 실행 시)
- **PostgreSQL** (>= 12, 로컬 실행 시)

### 로컬 개발 환경 설정

#### 1. 의존성 설치 및 빌드

```bash
# 의존성 설치 및 프로젝트 빌드
make setup
make build

# 또는 직접 Stack 명령어 사용
stack setup
stack build
```

#### 2. PostgreSQL 데이터베이스 준비

로컬에서 PostgreSQL을 실행하거나 Docker로 실행:

```bash
# Docker로 PostgreSQL만 실행
docker run -d \
  --name postgres-dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  postgres:16-alpine
```

#### 3. 환경변수 설정

```bash
export DB_HOST=127.0.0.1
export DB_PORT=5432
export DB_NAME=postgres
export DB_USER=postgres
export DB_PASSWORD=postgres
```

#### 4. 애플리케이션 실행

```bash
# Makefile 사용
make run

# 또는 Stack 직접 사용
stack exec postgresql-simple-init-exe
```

서버가 `http://0.0.0.0:8000`에서 시작됩니다.

### Docker Compose로 실행

전체 스택(PostgreSQL + 애플리케이션)을 Docker Compose로 실행:

```bash
# 서비스 시작
make docker-compose-up

# 로그 확인
make docker-compose-logs

# 서비스 중지 및 볼륨 삭제
make docker-compose-down
```

## 📡 API 엔드포인트

애플리케이션은 다음 HTTP 엔드포인트를 제공합니다:

### `GET /`

- **설명**: 루트 엔드포인트
- **응답**: `OK`

### `GET /health`

- **설명**: 헬스체크 엔드포인트
- **응답**: `healthy`

### `GET /users`

- **설명**: 모든 사용자 목록 조회
- **응답 예시**:

  ```
  1: Tomas
  ```

### `GET /users/detail?id=1`

- **설명**: 사용자 상세 조회
- **응답 예시**:

  ```
  1: Tomas
  ```

### `POST /users?id=1&name=Alice`

- **설명**: 사용자 생성 (id가 이미 있으면 무시)
- **응답**: `created` 또는 `skipped`

### `PUT /users?id=1&name=Alice2`

- **설명**: 사용자 정보 수정
- **응답**: `updated` 또는 `not-updated`

### `DELETE /users?id=1`

- **설명**: 사용자 삭제
- **응답**: `deleted` 또는 `not-deleted`

## 🧪 테스트

```bash
# 테스트 실행
make test

# 커버리지 포함 테스트
make coverage

# 파일 변경 감지 자동 테스트
make watch-test
```

## 🐳 Docker

### Docker 이미지 빌드

```bash
# 멀티스테이지 빌드로 이미지 생성
make docker-build

# 또는 직접 빌드
docker build --build-arg PROJECT_NAME=postgresql-simple-init \
  -t postgresql-simple-init:latest \
  -f docker/Dockerfile .
```

### Docker 컨테이너 실행

```bash
# 단독 실행 (PostgreSQL 별도 필요)
make docker-run

# 또는 직접 실행
docker run -it --rm \
  --name postgresql-simple-init-app \
  -p 8000:8000 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=postgres \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  postgresql-simple-init:latest
```

## 🔧 개발 도구

### 포맷팅부터 서버 실행까지

`fourmolu`, `stylish-haskell`, `hlint`, `stack`을 PATH에 추가하고 위의 PostgreSQL 실행 환경을 준비합니다. 스크립트는 Haskell 소스 파일을 제자리에서 포맷하고 HLint 결과를 출력한 뒤 빌드, 테스트, 서버 실행을 차례로 진행합니다. HLint 지적 사항이 있어도 빌드를 계속합니다.

```bash
./scripts/run.sh
```

```powershell
pwsh -File ./scripts/run.ps1
```

### GHCID (빠른 피드백)

```bash
# 파일 변경 시 자동 재컴파일
make ghcid
```

## 📦 빌드 산출물

### 로컬 설치

```bash
# 실행 파일을 ~/.local/bin에 설치
make install
```

### 릴리즈 빌드

```bash
# 최적화된 릴리즈 빌드
make release
```

## 🛠️ Makefile 주요 타겟

| 타겟 | 설명 |
|------|------|
| `make all` | 전체 빌드 파이프라인 실행 (clean → setup → build → test → run) |
| `make clean` | 빌드 아티팩트 정리 |
| `make setup` | 의존성 설치 |
| `make build` | 프로젝트 빌드 |
| `make test` | 테스트 실행 |
| `make run` | 애플리케이션 실행 |
| `make format` | 코드 포맷팅 |
| `make docker-build` | Docker 이미지 빌드 |
| `make docker-compose-up` | Docker Compose로 전체 스택 시작 |
| `make docker-compose-down` | Docker Compose 스택 중지 |

## 🔑 환경변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `DB_HOST` | `127.0.0.1` | PostgreSQL 호스트 |
| `DB_PORT` | `5432` | PostgreSQL 포트 |
| `DB_NAME` | `postgres` | 데이터베이스 이름 |
| `DB_USER` | `postgres` | 데이터베이스 사용자 |
| `DB_PASSWORD` | `postgres` | 데이터베이스 비밀번호 |

## 📚 주요 의존성

- **base**: Haskell 기본 라이브러리
- **postgresql-simple**: PostgreSQL 클라이언트 라이브러리
- **wai**: Web Application Interface
- **warp**: 고성능 HTTP 서버
- **flow**: 함수 합성 유틸리티
- **bytestring**: 효율적인 바이트 문자열 처리
- **http-types**: HTTP 타입 정의

## 📖 학습 포인트

이 프로젝트를 통해 다음을 학습할 수 있습니다:

1. **헥사고날 아키텍처**: 도메인 로직과 인프라를 분리하는 방법
2. **타입클래스 기반 추상화**: `UserRepository` 인터페이스를 통한 의존성 역전
3. **모나딕 패턴**: `PostgresRepo` 모나드를 통한 데이터베이스 연산 추상화
4. **Docker 멀티스테이지 빌드**: 경량화된 프로덕션 이미지 생성
5. **환경 기반 설정**: 12-Factor App 원칙 적용

## 📝 라이선스

BSD-3-Clause

## 👤 작성자

**Mingyu Choo**

- Email: <mingyuchoo@gmail.com>
- GitHub: [@mingyuchoo](https://github.com/mingyuchoo)

## 🤝 기여

이슈 제보와 풀 리퀘스트를 환영합니다!

---

**참고**: 이 프로젝트는 학습 목적으로 작성되었습니다.
