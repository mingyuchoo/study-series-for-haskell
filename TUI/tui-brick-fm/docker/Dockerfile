ARG PROJECT_NAME=hfm
FROM fpco/stack-build:lts-24.21
WORKDIR /app

ARG PROJECT_NAME
COPY stack.yaml stack.yaml.lock cabal.project ./
COPY README.md CHANGELOG.md LICENSE ./
COPY packages/ packages/
COPY apps/ apps/
COPY scripts/link-macos.sh scripts/link-macos.sh

RUN stack setup --no-docker && stack build --dependencies-only --no-docker

ARG PROJECT_NAME
RUN stack install --no-docker --local-bin-path /app/bin

RUN cp /app/bin/${PROJECT_NAME}-exe /app/bin/app-exe

CMD ["sh", "-c", "echo \"Starting app...\" && /app/bin/app-exe"]
