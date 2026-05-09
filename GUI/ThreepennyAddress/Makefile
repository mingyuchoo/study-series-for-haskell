SHELL := /usr/bin/env bash
.DEFAULT_GOAL := build

STACK ?= stack
PACKAGE_NAME := $(shell awk '/^name:/ { print $$2; exit }' package.yaml)
EXECUTABLE := $(PACKAGE_NAME)-exe
JOBS ?= 4
GHC_JOBS ?= 4
GUI_PORT ?= 8023

.PHONY: all setup deps clean build test coverage watch-test watch-coverage ghcid \
        format run release install docker-build docker-run docker-compose-up \
        docker-compose-down docker-compose-logs help

all: build test

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make build             Build the library and executable' \
	  '  make test              Run the test suite' \
	  '  make run               Run the Threepenny GUI on http://localhost:8023' \
	  '  make coverage          Run tests with coverage' \
	  '  make format            Format Haskell sources with stylish-haskell' \
	  '  make release           Build and copy the executable to dist/bin' \
	  '  make install           Install the executable to ~/.local/bin' \
	  '  make docker-build      Build the Docker image' \
	  '  make docker-run        Run the Docker image with port 8023 exposed'

setup:
	$(STACK) setup

deps:
	$(STACK) build --only-dependencies --test --no-run-tests

clean:
	$(STACK) clean
	rm -rf dist

build:
	$(STACK) build --fast -j$(JOBS) --ghc-options "-j$(GHC_JOBS) +RTS -A256m -RTS"

test:
	$(STACK) test --fast

coverage:
	$(STACK) test --coverage --fast --haddock

watch-test:
	$(STACK) test --fast --file-watch --watch-all

watch-coverage:
	$(STACK) test --coverage --fast --file-watch --watch-all --haddock

ghcid:
	ghcid --command "$(STACK) ghci"

format:
	stylish-haskell --config .stylish-haskell.yaml -r -i src app test

run:
	$(STACK) run $(EXECUTABLE)

release:
	mkdir -p dist/bin
	$(STACK) build --copy-bins --local-bin-path dist/bin -j$(JOBS) --ghc-options "-j$(GHC_JOBS) +RTS -A256m -RTS"

install: release
	mkdir -p $(HOME)/.local/bin
	cp dist/bin/$(EXECUTABLE) $(HOME)/.local/bin/

docker-build:
	docker build --build-arg PROJECT_NAME=$(PACKAGE_NAME) -t $(PACKAGE_NAME):latest -f docker/Dockerfile .

docker-run: docker-build
	mkdir -p data
	docker run -it --rm \
	  --name $(PACKAGE_NAME)-app \
	  -p $(GUI_PORT):8023 \
	  -v $(CURDIR)/data:/app/data \
	  $(PACKAGE_NAME):latest

docker-compose-up:
	PROJECT_NAME=$(PACKAGE_NAME) docker compose -f docker/docker-compose.yaml up --build -d

docker-compose-down:
	PROJECT_NAME=$(PACKAGE_NAME) docker compose -f docker/docker-compose.yaml down --volumes

docker-compose-logs:
	PROJECT_NAME=$(PACKAGE_NAME) docker compose -f docker/docker-compose.yaml logs -f
