# CurrencyExtension

A personal [Tuna](https://tunaformac.com) extension that converts an amount from one currency into
another. This fork keeps only that extension. It targets Tuna 0.110 and TunaKit 1.22.0, and it
requires Xcode 27 or later (Swift 6.4) to build. The extension runs on macOS 15 or later.

**Convert Currency** runs on text such as `100 usd eur`. It returns one copyable amount per target
currency and reads a default target (EUR) from the extension setting when the text has none.

## CurrencyCore

`CurrencyExtension/CurrencyCore` is a Swift package with no TunaKit or AppKit dependency. Test it
on Linux or macOS:

```bash
swift test --package-path CurrencyExtension/CurrencyCore
make test
```

The parser accepts an amount, a source currency, and optional targets (`100 usd eur`,
`100 usd to eur`, `$100 in yen`, `€50 gbp`, `12.5 usd eur`, names such as `dollars` and `yen`,
ISO codes in any case). Text that is not a conversion, including math, returns nil.

Rates come from the Frankfurter v1 API at `https://api.frankfurter.app/latest` (no API key, ECB
reference rates). A successful response is cached on disk for 12 hours. When a refresh fails, the
client returns the last cached table and reports the ECB date those rates came from. See
[CurrencyExtension/README.md](CurrencyExtension/README.md).

## Building and installing

On a Mac with Xcode 27 or later and Tuna 0.110, from this repository root:

```bash
./scripts/tuna-extension install --scheme CurrencyExtension --restart
```

The project ad-hoc signs, so the command does not need an Apple Developer team. It copies
`CurrencyExtension.framework` into `~/Library/Application Support/Tuna/ExtensionsDev` and restarts
Tuna. Details, plus how to import a workflow artifact, are in
[CurrencyExtension/README.md](CurrencyExtension/README.md).

```bash
make
./scripts/tuna-extension build --scheme CurrencyExtension
make ext-local TARGET=CurrencyExtension TUNA_ROOT=/absolute/path/to/Tuna
```

Open `TunaExtensions.xcworkspace` for Xcode work. After a dev install, restart Tuna to load changed
extension code. `ext-local` builds against a local TunaKit checkout without changing the checked-in
package pin.

TunaKit is pinned to `1.22.0` with an up-to-next-minor requirement, the same pin as FancyText in
[tunaformac/TunaExtensions](https://github.com/tunaformac/TunaExtensions). The package is in beta, so
raise that pin only after reading its [changelog](https://github.com/tunaformac/TunaKit/blob/main/CHANGELOG.md).

The `currency` GitHub Actions workflow is manual (`workflow_dispatch`). It is not a pull-request
check. When run, it uses the `xcode-27` runner, runs `swift test` for CurrencyCore, and uploads an
ad-hoc signed universal `CurrencyExtension.framework` zip. The extension's deployment target
remains macOS 15. Build logs are uploaded even when compilation fails.

TunaKit 1.22.0 contains a Swift 6.4 binary module interface; Xcode 26 and older cannot
compile it. Xcode 27 requires macOS 26.6 or later on the build machine. To keep an older
macOS version locally, run the Currency workflow and import its framework artifact instead.

## Packaging

```bash
make release TARGET=CurrencyExtension
```

Packaging reads `minTuna` and `minTunaKit` from the Swift declaration and needs a Tuna binary
(`TUNA_BINARY`, a debug build under `TUNA_ROOT`, or `/Applications/Tuna.app`). Docs for the
extension API live at https://tunaformac.com/docs.

## License

TunaExtensions is available under the [MIT License](LICENSE).
