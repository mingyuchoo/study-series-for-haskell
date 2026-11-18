# 프로젝트 이름을 ARG로 받아서 사용
ARG PROJECT_NAME=servant-t03-clean-archi
FROM node:24-bookworm-slim AS frontend
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/todo-web/package.json apps/todo-web/package.json
RUN npm ci
COPY apps/todo-web/elm.json apps/todo-web/elm.json
COPY apps/todo-web/src/ apps/todo-web/src/
RUN npm run build

# 빌드와 실행을 동일한 이미지에서 진행
FROM fpco/stack-build:lts
WORKDIR /app

# 프로젝트에 필요한 모든 파일들을 복사
# 설정 파일들
ARG PROJECT_NAME
COPY stack.yaml stack.yaml.lock package.yaml ${PROJECT_NAME}.cabal Setup.hs ./
COPY README.md CHANGELOG.md LICENSE ./
# 소스 디렉토리들
COPY src/ src/
COPY app/ app/
COPY test/ test/
COPY static/ static/
COPY --from=frontend /app/static/js/elm.js static/js/elm.js

# 프로젝트 설정 및 의존성 설치
RUN stack setup --no-docker && stack build --dependencies-only --no-docker

# 프로젝트 빌드
ARG PROJECT_NAME
RUN stack install --no-docker --local-bin-path /app/bin

# 실행 파일 이름 고정
RUN cp /app/bin/${PROJECT_NAME}-exe /app/bin/app-exe 

# 포트 노출
EXPOSE 8000

# 실행
CMD ["sh", "-c", "echo \"Starting server on port 8000...\" && /app/bin/app-exe"]
