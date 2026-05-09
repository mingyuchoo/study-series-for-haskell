.PHONY: all help check-system-deps setup deps build test coverage run ghci watch-build watch-test install clean distclean format hpack

STACK ?= stack
HPACK ?= hpack
PACKAGE := MonomerApp
EXECUTABLE := app
PKG_CONFIG_PACKAGES := sdl2 glew

all: build

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  check-system-deps  Check Monomer native dependencies via pkg-config' \
	  '  setup              Install/select the compiler from stack.yaml' \
	  '  deps               Build project dependencies' \
	  '  build              Build the executable' \
	  '  test               Build and run test suites when present' \
	  '  coverage           Run tests with coverage enabled when present' \
	  '  run                Run the Monomer application from the project root' \
	  '  ghci               Open a Stack GHCi session for the executable' \
	  '  watch-build        Rebuild on file changes' \
	  '  watch-test         Re-run tests on file changes' \
	  '  install            Install the executable into Stack local bin' \
	  '  clean              Remove Stack build artifacts for this project' \
	  '  distclean          Remove the local Stack work directory' \
	  '  format             Run ./format.sh' \
	  '  hpack              Regenerate MonomerApp.cabal from package.yaml'

check-system-deps:
	@missing=0; \
	for package in $(PKG_CONFIG_PACKAGES); do \
	  if ! pkg-config --exists "$$package"; then \
	    printf 'Missing pkg-config package: %s\n' "$$package"; \
	    missing=1; \
	  fi; \
	done; \
	if [ "$$missing" -ne 0 ]; then \
	  printf '\nInstall Monomer native dependencies first:\n'; \
	  printf '  Ubuntu/Debian: sudo apt-get install pkg-config libsdl2-dev libglew-dev\n'; \
	  printf '  Fedora:        sudo dnf install pkgconf-pkg-config SDL2-devel glew-devel\n'; \
	  printf '  macOS:         brew install pkg-config sdl2 glew\n'; \
	  exit 1; \
	fi

setup:
	$(STACK) setup

deps: check-system-deps
	$(STACK) build --only-dependencies --test --no-run-tests

build: check-system-deps
	$(STACK) build --fast $(PACKAGE):exe:$(EXECUTABLE)

test: check-system-deps
	$(STACK) test --fast

coverage: check-system-deps
	$(STACK) test --coverage --fast

run: check-system-deps
	$(STACK) run $(PACKAGE):exe:$(EXECUTABLE)

ghci: check-system-deps
	$(STACK) ghci $(PACKAGE):exe:$(EXECUTABLE)

watch-build: check-system-deps
	$(STACK) build --fast --file-watch $(PACKAGE):exe:$(EXECUTABLE)

watch-test: check-system-deps
	$(STACK) test --fast --file-watch --watch-all

install: check-system-deps
	$(STACK) install $(PACKAGE):exe:$(EXECUTABLE)

clean:
	$(STACK) clean

distclean: clean
	rm -rf .stack-work

format:
	./format.sh

hpack:
	$(HPACK)
