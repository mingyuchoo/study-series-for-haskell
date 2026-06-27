# syntax=docker/dockerfile:1
#
# 단일 컨테이너: Haskell/Servant 백엔드가 빌드된 Solid.js SPA 정적 파일까지 서빙한다.
#   - /api/*  → Servant API
#   - 그 외   → frontend/dist 정적 파일 (없으면 index.html 폴백, SPA 라우팅)

# ---------- Stage 1: 프런트엔드(SPA) 빌드 ----------
FROM node:20-bookworm-slim AS frontend
WORKDIR /app
# 워크스페이스 매니페스트만 먼저 복사해 의존성 설치 레이어를 캐시한다.
COPY package.json package-lock.json ./
COPY frontend/package.json ./frontend/
RUN npm ci
# 소스 복사 후 빌드 → frontend/dist 생성
COPY frontend/ ./frontend/
RUN npm run build:frontend

# ---------- Stage 2: 백엔드(Haskell) 빌드 ----------
FROM haskell:9.6.6 AS backend
WORKDIR /build
# postgresql-simple 빌드에 libpq 헤더가 필요하다.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && rm -rf /var/lib/apt/lists/*
# 의존성 캐시: cabal 매니페스트만 먼저 복사해 의존성 빌드를 캐시한다(소스 변경 시 재컴파일 최소화).
COPY backend/luck-backend.cabal backend/cabal.project ./
RUN cabal update && cabal build --only-dependencies
# 소스 복사 후 빌드/설치. migrations/ 는 file-embed 로 바이너리에 내장된다.
COPY backend/ ./
RUN cabal install exe:luck-backend --install-method=copy --installdir=/out

# ---------- Stage 3: 런타임 ----------
FROM debian:bookworm-slim AS runtime
WORKDIR /app
# Haskell 바이너리가 동적 링크하는 공유 라이브러리 + TLS 루트 인증서(DB sslmode=require).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 libgmp10 libffi8 zlib1g ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# 백엔드 실행 바이너리
COPY --from=backend /out/luck-backend /usr/local/bin/luck-backend
# 빌드된 SPA 정적 파일 → STATIC_DIR 가 가리키는 경로
COPY --from=frontend /app/frontend/dist ./static
# UTF-8 로케일 강제: 미설정 시 GHC 의 stdout/stderr 핸들이 ASCII 로 동작해
# 한글 로그(예: 설정 경고/에러 메시지) 출력 시 "commitBuffer: invalid argument
# (cannot encode character ...)" 로 프로세스가 죽는다. C.UTF-8 은 locales 패키지
# 없이도 항상 사용 가능하다.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PORT=8080
ENV STATIC_DIR=/app/static
EXPOSE 8080
CMD ["luck-backend"]
