FROM node:22-bookworm-slim AS frontend
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /frontend
COPY package.json package-lock.json ./
COPY apps/frontend/package.json apps/frontend/package.json
RUN npm ci
COPY apps/frontend/elm.json apps/frontend/elm.json
COPY apps/frontend/src/ apps/frontend/src/
COPY www/index.html www/styles.css www/
RUN npm run build

FROM fpco/stack-build:lts
ARG PROJECT_NAME=warp-t03-clean-archi
WORKDIR /app
COPY stack.yaml package.yaml ${PROJECT_NAME}.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./
COPY src/ src/
COPY app/ app/
COPY test/ test/
COPY --from=frontend /frontend/www/ www/
RUN stack setup --no-docker && stack build --dependencies-only --no-docker
RUN stack install --no-docker --local-bin-path /app/bin
RUN cp /app/bin/${PROJECT_NAME}-exe /app/bin/app-exe
EXPOSE 8000
CMD ["/app/bin/app-exe"]
