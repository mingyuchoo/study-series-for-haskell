FROM haskell:9.14.1-slim-bookworm
WORKDIR /app

COPY stack.yaml stack.yaml.lock package.yaml fzh.cabal Setup.hs cabal.project ./
COPY README.md CHANGELOG.md LICENSE ./
COPY packages/ packages/
COPY apps/ apps/

RUN stack setup --no-docker && stack build --dependencies-only --no-docker
RUN stack install --no-docker --local-bin-path /app/bin

CMD ["/app/bin/fzh-exe"]
