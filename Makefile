# This fork ships CurrencyExtension only.
EXTENSION_SCHEMES := CurrencyExtension
INSTALL_DIR := $(HOME)/Library/Application Support/Tuna/ExtensionsDev
LOCAL_DERIVED_DATA := ./build/dd-local
CONFIGURATION ?= Debug

.DEFAULT_GOAL := build-all
.PHONY: build-all test test-release-scripts test-local-tunakit-rewrite ext ext-all ext-local ext-all-local ext-package ext-upload release release-all clean

define require_target
	@test -n "$(TARGET)" || { echo "usage: make $@ TARGET=<Scheme>" >&2; exit 64; }
endef

define require_tuna_root
	@test -n "$(TUNA_ROOT)" || { echo "usage: make $@ TUNA_ROOT=/absolute/path/to/Tuna" >&2; exit 64; }
endef

# Compile CurrencyExtension in Release.
build-all:
	@set -e; for SCHEME in $(EXTENSION_SCHEMES); do echo "=== $$SCHEME ==="; ./scripts/tuna-extension build --scheme "$$SCHEME" --release >/dev/null; done; echo "CurrencyExtension builds."

# CurrencyCore has no TunaKit dependency, so its tests run with swift test.
test:
	swift test --package-path CurrencyExtension/CurrencyCore

test-release-scripts:
	@./tests/release-all-extensions-test.sh
	@./tests/cross-repo-paths-test.sh
	@./tests/run-xcodebuild-test.sh
	@./tests/local-tunakit-rewrite-test.sh
	@./tests/local-extension-tooling-test.sh

test-local-tunakit-rewrite:
	@./tests/local-tunakit-rewrite-test.sh

# Build one extension and install it into Tuna's ExtensionsDev for local development.
ext:
	$(require_target)
	@./scripts/tuna-extension install --scheme "$(TARGET)"

# Dev-install every extension.
ext-all:
	@set -e; for SCHEME in $(EXTENSION_SCHEMES); do ./scripts/tuna-extension install --scheme "$$SCHEME"; done

# Build selected extensions against Tuna's local TunaKit source and dev-install them. TARGET keeps
# the original single-target interface; TARGETS accepts a space-separated subset.
ext-local:
	$(require_tuna_root)
	@test -n "$(strip $(TARGET) $(TARGETS))" || { echo "usage: make $@ TARGET=<Scheme> or TARGETS='<Scheme> ...' TUNA_ROOT=/absolute/path/to/Tuna [CONFIGURATION=Release]" >&2; exit 64; }
	@./scripts/install-local-extensions.sh \
	  "$(TUNA_ROOT)" "$(INSTALL_DIR)" "$(LOCAL_DERIVED_DATA)" "$(CONFIGURATION)" \
	  $(strip $(TARGET) $(TARGETS))

# Build every extension against Tuna's local TunaKit source and dev-install it.
ext-all-local:
	$(require_tuna_root)
	@./scripts/install-local-extensions.sh \
	  "$(TUNA_ROOT)" "$(INSTALL_DIR)" "$(LOCAL_DERIVED_DATA)" "$(CONFIGURATION)" \
	  $(EXTENSION_SCHEMES)

# Build + package one extension as a .tunaextension store artifact.
# Needs a Tuna binary for the declaration dump: /Applications/Tuna.app or TUNA_BINARY.
ext-package:
	$(require_target)
	@./scripts/tuna-extension package --scheme "$(TARGET)"

# Build + upload one extension to the store API.
ext-upload:
	$(require_target)
	@./scripts/tuna-extension upload --scheme "$(TARGET)"

# Test, build, publish, verify, tag, and push one extension.
release: test
	$(require_target)
	@./scripts/tuna-extension release --scheme "$(TARGET)"

# Prepare and preflight every extension before publishing any of them.
release-all: test
	@./scripts/release-all-extensions.sh $(EXTENSION_SCHEMES)

clean:
	rm -rf ./build
