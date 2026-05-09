.PHONY: all help check-system-deps setup deps build test coverage run ghci watch-test watch-build install clean distclean format

STACK ?= stack
PACKAGE := GiGtkApp
EXECUTABLE := GiGtkApp-exe
PKG_CONFIG_PACKAGES := gobject-introspection-1.0 gtk4

all: build test

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  check-system-deps  Check GTK/GObject Introspection development packages' \
	  '  setup        Install/select the compiler from stack.yaml' \
	  '  deps         Build project dependencies' \
	  '  build        Build the library and executable' \
	  '  test         Run the test suite' \
	  '  coverage     Run tests with coverage enabled' \
	  '  run          Run the GTK application' \
	  '  ghci         Open a Stack GHCi session' \
	  '  watch-test   Re-run tests on file changes' \
	  '  watch-build  Rebuild on file changes' \
	  '  install      Install the executable into Stack local bin' \
	  '  clean        Remove Stack build artifacts for this project' \
	  '  distclean    Remove the local Stack work directory' \
	  '  format       Run ./format.sh'

check-system-deps:
	@missing=0; \
	for package in $(PKG_CONFIG_PACKAGES); do \
	  if ! pkg-config --exists "$$package"; then \
	    printf 'Missing pkg-config package: %s\n' "$$package"; \
	    missing=1; \
	  fi; \
	done; \
	if [ "$$missing" -ne 0 ]; then \
	  printf '\nInstall GTK/GObject Introspection development packages first:\n'; \
	  printf '  Ubuntu/Debian: sudo apt-get install libgirepository1.0-dev libgtk-4-dev\n'; \
	  printf '  Fedora:        sudo dnf install gobject-introspection-devel gtk4-devel\n'; \
	  printf '  macOS:         brew install gtk4 gobject-introspection\n'; \
	  exit 1; \
	fi

setup:
	$(STACK) setup

deps: check-system-deps
	$(STACK) build --only-dependencies --test --no-run-tests

build: check-system-deps
	$(STACK) build --fast

test: check-system-deps
	$(STACK) test --fast

coverage: check-system-deps
	$(STACK) test --coverage --fast

run: check-system-deps
	$(STACK) run $(EXECUTABLE)

ghci: check-system-deps
	$(STACK) ghci $(PACKAGE):lib $(PACKAGE):exe:$(EXECUTABLE)

watch-test: check-system-deps
	$(STACK) test --fast --file-watch --watch-all

watch-build: check-system-deps
	$(STACK) build --fast --file-watch

install: check-system-deps
	$(STACK) install $(PACKAGE):exe:$(EXECUTABLE)

clean:
	$(STACK) clean

distclean: clean
	rm -rf .stack-work

format:
	./format.sh
