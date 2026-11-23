FROM fpco/stack-build:lts AS dependencies

WORKDIR /build

COPY stack.yaml stack.yaml.lock ./
COPY package.yaml *.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./

RUN stack setup --no-docker && \
    stack build --only-dependencies --no-docker

FROM fpco/stack-build:lts AS builder

WORKDIR /build

COPY --from=dependencies /root/.stack /root/.stack
COPY --from=dependencies /build/.stack-work /build/.stack-work

COPY stack.yaml stack.yaml.lock package.yaml *.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./

COPY src/ src/
COPY app/ app/
COPY test/ test/

ARG PROJECT_NAME=postgresql-simple-init
RUN stack build --no-docker --copy-bins --local-bin-path /build/bin

RUN cp /build/bin/${PROJECT_NAME}-exe /build/bin/app-exe

RUN set -eux; \
    mkdir -p /build/lib; \
    ldd /build/bin/app-exe | awk '{print $3}' | grep -E '^/root/.stack|^/build/.stack-work' | while read -r so; do \
      if [ -f "$so" ]; then \
        cp -v --parents "$so" /build/lib || true; \
      fi; \
    done; \
    find /build/lib -type f -name '*.so*' -exec bash -c 'for f; do base=$(basename "$f"); dest="/build/lib/$base"; [ -e "$dest" ] || mv -v "$f" "$dest"; done' _ {} +; \
    find /build/lib -type d -empty -delete || true

FROM ubuntu:22.04 AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libgmp10 \
        libpq5 \
        libsqlite3-0 \
        netbase \
        locales && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/bin/app-exe /app/

COPY --from=builder /build/lib/ /app/lib/
RUN echo "/app/lib" > /etc/ld.so.conf.d/app.conf && ldconfig

RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

COPY static/ /app/static/

RUN mkdir -p /app/data

EXPOSE 8000

CMD ["/app/app-exe"]
