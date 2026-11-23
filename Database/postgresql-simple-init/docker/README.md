# Docker 빌드 가이드

## 멀티 스테이지 빌드 구조

이 Dockerfile은 3단계 멀티 스테이지 빌드를 사용하여 빌드 속도와 이미지 크기를 최적화합니다:

### 1단계: 의존성 캐시 (dependencies)

- Stack 설정 및 프로젝트 메타데이터만 복사
- 의존성 패키지만 빌드
- 소스 코드 변경 시 이 레이어는 캐시에서 재사용됨

### 2단계: 애플리케이션 빌드 (builder)

- 1단계에서 빌드한 의존성 재사용
- 소스 코드 복사 및 애플리케이션 빌드
- 실행 파일 생성

### 3단계: 런타임 이미지 (runtime)

- 경량 Ubuntu 베이스 이미지 사용
- 필요한 런타임 라이브러리만 설치
- 빌드된 실행 파일과 정적 파일만 복사
- 최종 이미지 크기 최소화

## 빌드 방법

### 프로젝트 루트에서 빌드

```bash
cd /home/mgch/github/mingyuchoo/haskell-study-series/Database/postgresql-simple-init
docker build -t postgresql-simple-init:latest -f docker/Dockerfile .
```

### 빌드 인자 사용

```bash
docker build \
  --build-arg PROJECT_NAME=postgresql-simple-init \
  -t postgresql-simple-init:latest \
  -f docker/Dockerfile .
```

## 실행 방법

### Docker Compose로 실행 (PostgreSQL 포함)

```bash
docker compose -f docker/docker-compose.yaml up --build
```

PowerShell:

```powershell
docker compose -f docker/docker-compose.yaml up --build
```

## 최적화 팁

1. **빌드 캐시 활용**: 의존성이 변경되지 않으면 1단계가 캐시에서 재사용됩니다.
2. **병렬 빌드**: Docker BuildKit을 사용하여 빌드 속도를 향상시킬 수 있습니다:

   ```bash
   DOCKER_BUILDKIT=1 docker build -t postgresql-simple-init:latest -f docker/Dockerfile .
   ```

3. **이미지 크기**: 최종 런타임 이미지는 빌드 도구 없이 필요한 런타임만 포함합니다.

## 테스트 (엔드포인트)

```bash
curl "http://localhost:8000/health"
curl "http://localhost:8000/users"
curl "http://localhost:8000/users/detail?id=1"
curl -X POST "http://localhost:8000/users?id=2&name=Alice"
curl -X PUT  "http://localhost:8000/users?id=2&name=Alice2"
curl -X DELETE "http://localhost:8000/users?id=2"
```

PowerShell:

```powershell
irm "http://localhost:8000/health"
irm "http://localhost:8000/users"
irm "http://localhost:8000/users/detail?id=1"
```
