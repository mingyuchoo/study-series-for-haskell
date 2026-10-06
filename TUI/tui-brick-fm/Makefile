.PHONY: test coverage install update-stack-yaml check-architecture

# Cabal package name (independent of checkout directory name)
PROJECT_NAME := hfm

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
	rg --files packages apps -g '*.hs' | xargs stylish-haskell --config .stylish-haskell.yaml -i

build: setup
	stack build --fast -j4 --ghc-options "-j16 +RTS -A256m -RTS"

check-architecture:
	python3 scripts/check-architecture.py
	python3 scripts/test-architecture.py

test: setup check-architecture
	stack test --fast

coverage: setup
	stack test --coverage --fast --haddock

watch-test: setup check-architecture
	stack test --fast --file-watch --watch-all

watch-coverage: setup
	stack test --coverage --fast --file-watch --watch-all --haddock

ghcid: setup
	ghcid --command "stack ghci hfm-application:test:hfm-application-test"

run: build
	time stack exec $(PROJECT_NAME)-exe

release: setup
	stack build -j4 --ghc-options "-j16 +RTS -A256m -RTS"

docker-build: release
	docker build --build-arg PROJECT_NAME=$(PROJECT_NAME) -t $(PROJECT_NAME):latest -f docker/Dockerfile .

docker-build-multi:
	docker build --build-arg PROJECT_NAME=$(PROJECT_NAME) -t $(PROJECT_NAME):latest -f docker/Dockerfile .

docker-run: docker-build
	mkdir -p ./data
	docker run -it --rm \
	  --name $(PROJECT_NAME)-app \
	  -v $(PWD)/data:/app/data \
	  $(PROJECT_NAME):latest

docker-compose-up:
	docker compose -f docker/docker-compose.yaml up --build -d

docker-compose-down:
	docker compose -f docker/docker-compose.yaml down --volumes

docker-compose-logs:
	docker compose -f docker/docker-compose.yaml logs -f

install: release
	mkdir -p $(HOME)/.local/bin
	cp $(shell stack path --local-install-root)/bin/$(PROJECT_NAME)-exe $(HOME)/.local/bin/

