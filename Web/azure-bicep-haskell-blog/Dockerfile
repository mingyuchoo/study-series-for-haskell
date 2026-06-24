# syntax=docker/dockerfile:1

# ============================================================
# Build stage — GHC 9.8 + cabal (libpq 링크 필요)
# ============================================================
FROM haskell:9.8-slim AS builder

# postgresql-simple는 libpq에 링크된다. 또한 postgresql-libpq-configure(0.11+)는
# libpq >= 14.12 를 요구하는데, haskell:9.8-slim(Debian bullseye)의 libpq-dev는 13 이라
# 그대로는 빌드가 실패한다. PostgreSQL 공식 저장소(PGDG)에서 최신 libpq-dev 를 설치한다.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates gnupg wget zlib1g-dev \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1) 의존성 레이어 캐싱: cabal 메타데이터만 먼저 복사
COPY haskell-blog.cabal cabal.project ./
RUN cabal update && cabal build --only-dependencies -j

# 2) 소스 복사 후 실행 파일 빌드
COPY . .
RUN cabal build exe:haskell-blog -j \
    && mkdir -p /app/bin \
    && cp "$(cabal list-bin exe:haskell-blog)" /app/bin/haskell-blog

# ============================================================
# Runtime stage — glibc 기반 debian-slim (musl/alpine 회피)
# ============================================================
FROM debian:bookworm-slim AS runtime

# GHC 동적 링크 바이너리 런타임 의존성: libpq5, libgmp10, zlib1g
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq5 libgmp10 zlib1g ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 비루트 사용자로 실행
RUN useradd --system --create-home --uid 10001 appuser
USER appuser
WORKDIR /home/appuser

COPY --from=builder /app/bin/haskell-blog /usr/local/bin/haskell-blog

# 로케일을 UTF-8 로 두어 한글 등 비ASCII 로그 출력 시 인코딩 오류를 방지한다.
# C.UTF-8 은 locales 패키지 없이도 사용 가능하다.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PORT=8080
EXPOSE 8080
CMD ["haskell-blog"]
