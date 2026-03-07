ARG PROJECT_NAME=demo-Free-Monad-db
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

ARG PROJECT_NAME
RUN stack install --no-docker --local-bin-path /app/bin

RUN cp /app/bin/${PROJECT_NAME}-exe /app/bin/app-exe 

EXPOSE 8000

CMD ["sh", "-c", "echo \"Starting server on port 8000...\" && /app/bin/app-exe"]