.PHONY: test coverage install update-stack-yaml

# Extract project name from directory path
PROJECT_NAME := $(shell basename $(CURDIR))

all: clean setup build test run

clean:
	stack clean

update-stack-yaml:
	@if [ "`uname`" = "Darwin" ]; then \
	  sed -i '' 's/container-name: ".*"/container-name: "$(PROJECT_NAME)"/g' stack.yaml; \
	  sed -i '' 's/ARG PROJECT_NAME=.*/ARG PROJECT_NAME=$(PROJECT_NAME)/g' docker/Dockerfile; \
	else \
	  sed -i 's/container-name: ".*"/container-name: "$(PROJECT_NAME)"/g' stack.yaml; \
	  sed -i 's/ARG PROJECT_NAME=.*/ARG PROJECT_NAME=$(PROJECT_NAME)/g' docker/Dockerfile; \
	fi

setup: update-stack-yaml
	stack setup
	stack test --only-dependencies

format: setup
	stylish-haskell --config .stylish-haskell.yaml -r -i ./**/*.hs

build: setup
	stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"

test: setup
	stack test --fast

coverage: setup
	stack test --coverage --fast --haddock

watch-test: setup
	stack test --fast --file-watch --watch-all

watch-coverage: setup
	stack test --coverage --fast --file-watch --watch-all --haddock

ghcid: setup
	ghcid --command "stack ghci test/Spec.hs"

run: setup
	time stack exec $(PROJECT_NAME)-exe

release: setup
	stack build -j4 --ghc-options "-j16 +RTS -A256m -RTS" --docker

docker-build: release
	# 멀티스테이지 Dockerfile 사용 (docker/Dockerfile)
	docker build --build-arg PROJECT_NAME=$(PROJECT_NAME) -t $(PROJECT_NAME):latest -f docker/Dockerfile .

docker-build-multi: 
	docker build --build-arg PROJECT_NAME=$(PROJECT_NAME) -t $(PROJECT_NAME):latest -f docker/Dockerfile .

docker-run: docker-build
	# 앱 포트 8000 노출 및 데이터 볼륨 마운트
	mkdir -p ./data
	docker run -it --rm \
	  --name $(PROJECT_NAME)-app \
	  -p 8000:8000 \
	  -v $(PWD)/data:/app/data \
	  $(PROJECT_NAME):latest

docker-run-multi: docker-build-multi
	docker run -it --rm -p 8000:8000 $(PROJECT_NAME):latest

docker-compose-up:
	docker compose -f docker/docker-compose.yaml up --build -d

docker-compose-down:
	docker compose -f docker/docker-compose.yaml down --volumes

docker-compose-logs:
	docker compose -f docker/docker-compose.yaml logs -f

install: release
	mkdir -p $(HOME)/.local/bin
	cp $(shell stack path --local-install-root)/bin/$(PROJECT_NAME)-exe $(HOME)/.local/bin/
