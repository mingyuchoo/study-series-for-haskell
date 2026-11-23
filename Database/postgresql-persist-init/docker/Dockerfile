ARG PROJECT_NAME=postgresql-persist-init
FROM fpco/stack-build:lts
WORKDIR /app

ARG PROJECT_NAME
COPY stack.yaml stack.yaml.lock package.yaml ${PROJECT_NAME}.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./
COPY src/ src/
COPY app/ app/
COPY test/ test/
COPY static/ static/

RUN stack setup --no-docker && stack build --dependencies-only --no-docker

RUN stack build --no-docker

RUN stack install --no-docker --local-bin-path /app/bin

EXPOSE 8000

CMD ["sh", "-c", "echo \"Starting server on port 8000...\" && /app/bin/run-server"]
