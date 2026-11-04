# TunaExtensions Agent Guide

Keep changes small and readable, and keep the closest user/developer documentation in sync.

## Checkout roots

Never infer one checkout from the current directory or a relative `../Tuna` path. Resolve the
checkout you are working in and pass cross-repository roots explicitly:

```sh
EXTENSIONS_ROOT="$(git rev-parse --show-toplevel)"
TUNA_ROOT="$(git -C /path/to/Tuna rev-parse --show-toplevel)"
```

When starting from a Tuna checkout or linked worktree, prefer its wrapper:

```sh
"$TUNA_ROOT/scripts/tuna-extensions.sh" ext-local TARGET=MyMindExtension
```

It resolves TunaExtensions from Tuna's primary checkout (or `TUNA_EXTENSIONS_ROOT`), then passes
the exact `TUNA_ROOT` and `TUNA_BINARY`. Otherwise use an explicit working directory, for example
`make -C "$EXTENSIONS_ROOT" test-release-scripts` or `cd "$EXTENSIONS_ROOT"`; do not rely on the
caller's current directory.

## Tooling gates

This fork contains CurrencyExtension only.

- Core unit tests: `make -C "$EXTENSIONS_ROOT" test`
- Release build: `make -C "$EXTENSIONS_ROOT"`
- One extension: `./scripts/tuna-extension build|install --scheme CurrencyExtension`

Xcode commands belong behind `scripts/run-xcodebuild`; it retains complete logs under
`build/xcodebuild`, uses `xcsift` for builds and tests when installed, and prints concise failure
diagnostics.
