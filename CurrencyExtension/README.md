# Currency

Convert an amount from one currency into one or more others inside Tuna.

Requires Tuna 0.80 or later and TunaKit 1.14.0. Build with Xcode 16 or later on macOS 15 or later.
This extension pins TunaKit 1.14.0 on purpose. The other extensions in this repository pin a newer TunaKit.

**Convert Currency** is declared and nothing more. It accepts a text snippet and returns a failure
until a follow-up wires it to the parser and rates client. It does not call the network.

## CurrencyCore

`CurrencyCore` is a Swift package inside this directory. It does not import TunaKit or AppKit, so
`swift test` runs on Linux and macOS:

```bash
swift test --package-path CurrencyExtension/CurrencyCore
```

The parser accepts an amount, a source currency, and optional targets:

- `100usd eur`, `100 usd eur`, `100 usd to eur`, `100 usd in eur`
- `$100 in yen`, `€50 gbp`, `£20 to usd`, `¥1000 usd`
- `100 usd` with a default target supplied by the caller
- decimals (`12.5 usd eur`), any letter case, and the names dollar/dollars, euro/euros, pound/pounds, and yen

Recognized codes are the currencies Frankfurter currently publishes. Anything that is not a
conversion, including math expressions such as `2+2`, returns nil so the action can hide itself.

Rates come from the Frankfurter v1 API at `https://api.frankfurter.app/latest` (no API key, ECB
reference rates). The host redirects to `api.frankfurter.dev`; the client follows that redirect.
A successful response is cached on disk for 12 hours. When a refresh fails, the client returns the
last cached table and reports the ECB date those rates came from.

The request sends only the base currency code. Amounts stay on device. Frankfurter does not require
an account, and its public instance does not log request URLs. The cache is a JSON file per base
currency in a directory the caller chooses.

## Build

```bash
xcodebuild build \
  -project CurrencyExtension/CurrencyExtension.xcodeproj \
  -scheme CurrencyExtension \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

This scheme is not part of `make` or `release-all`. Those commands build the TunaKit 1.22 extensions.
The `currency` GitHub Actions workflow is manual (`workflow_dispatch`) and is not a pull-request check. When run, it uses `macos-26-intel`. The extension's deployment target remains macOS 15.
