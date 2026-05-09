SHELL := /usr/bin/env bash

APP_NAME := app
STACK := stack
CABAL := cabal
HPACK := hpack

.DEFAULT_GOAL := help

.PHONY: help all build test run repl ghci cabal-build cabal-run hpack format lint release-linux release-macos release-windows clean dist-clean

help:
	@printf '%s\n' 'Available targets:'
	@printf '  %-14s %s\n' 'all' 'Build and test the project'
	@printf '  %-14s %s\n' 'build' 'Build the MonomerTodo executable with Stack'
	@printf '  %-14s %s\n' 'test' 'Run the Stack test command'
	@printf '  %-14s %s\n' 'run' 'Run the GUI application with Stack'
	@printf '  %-14s %s\n' 'repl' 'Start a Stack REPL for the app executable'
	@printf '  %-14s %s\n' 'cabal-build' 'Build with cabal-install'
	@printf '  %-14s %s\n' 'cabal-run' 'Run with cabal-install'
	@printf '  %-14s %s\n' 'hpack' 'Regenerate MonomerTodo.cabal from package.yaml'
	@printf '  %-14s %s\n' 'format' 'Format Haskell sources with ./scripts/format.sh'
	@printf '  %-14s %s\n' 'lint' 'Run hlint on src'
	@printf '  %-14s %s\n' 'release-linux' 'Build .deb and .rpm packages'
	@printf '  %-14s %s\n' 'release-macos' 'Build a .dmg package on macOS'
	@printf '  %-14s %s\n' 'release-windows' 'Build a .msi package with PowerShell/WiX'
	@printf '  %-14s %s\n' 'clean' 'Clean Stack and Cabal build artifacts'
	@printf '  %-14s %s\n' 'dist-clean' 'Clean build artifacts and the local SQLite database'

all: build test

build:
	$(STACK) build

test:
	$(STACK) test

run:
	$(STACK) exec $(APP_NAME)

repl ghci:
	$(STACK) repl --main-is MonomerTodo:exe:$(APP_NAME)

cabal-build:
	$(CABAL) build

cabal-run:
	$(CABAL) run $(APP_NAME)

hpack:
	$(HPACK)

format:
	./scripts/format.sh

lint:
	hlint src

release-linux:
	./scripts/release.sh linux

release-macos:
	./scripts/release.sh macos

release-windows:
	pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/release.ps1

clean:
	$(STACK) clean
	$(CABAL) clean

dist-clean: clean
	rm -f todos.db todos.db-shm todos.db-wal
