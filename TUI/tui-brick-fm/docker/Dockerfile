ARG PROJECT_NAME=fzh
FROM fpco/stack-build:lts-24.21
WORKDIR /app

ARG PROJECT_NAME
COPY stack.yaml stack.yaml.lock package.yaml ${PROJECT_NAME}.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./
COPY src/ src/
COPY app/ app/
COPY test/ test/

RUN stack setup --no-docker && stack build --dependencies-only --no-docker

ARG PROJECT_NAME
RUN stack install --no-docker --local-bin-path /app/bin

RUN cp /app/bin/${PROJECT_NAME}-exe /app/bin/app-exe

CMD ["sh", "-c", "echo \"Starting app...\" && /app/bin/app-exe"]
