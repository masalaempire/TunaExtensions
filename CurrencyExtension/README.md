# Currency

Convert an amount from one currency into one or more others inside Tuna.

Requires Tuna 0.110 and TunaKit 1.22.0. Build with Xcode 16 or later on macOS 15 or later.
TunaKit is pinned to 1.22.0, the same revision FancyText uses on tunaformac/TunaExtensions.
Tuna 0.95 and later do not load extensions built against TunaKit 1.20 or earlier.

Type an amount and a currency in Tuna's text mode, for example `100usd eur`, and press Return.
**Convert Currency** appears only when that text parses as a conversion. It returns one result
per target currency, such as `€92.40`. Each result is a text snippet, so Copy and Paste use that
amount. The row's detail is the ECB rate date. When the rate comes from the offline cache, the
detail says so and names that date, for example `Offline rates from 2024-01-15`. If Frankfurter
cannot be reached and there is no saved table, the action shows an inline error.

## Setting

**Default target currency** is an extension setting. Action catalogs still cannot carry settings,
so it is declared on the extension and shown on the Currency page in Settings → Sources. It
defaults to EUR. Text with no target, such as `100 usd`, converts into that currency. The value
is also the `DefaultTargetCurrency` key under this extension's bundle id,
`com.masalaempire.tuna.plugins.currency`, in `config.toml`.

## CurrencyCore

`CurrencyCore` is a Swift package inside this directory. It does not import TunaKit or AppKit, so
`swift test` runs on Linux and macOS:

```bash
swift test --package-path CurrencyExtension/CurrencyCore
```

The parser accepts an amount, a source currency, and optional targets:

- `100usd eur`, `100 usd eur`, `100 usd to eur`, `100 usd in eur`
- `$100 in yen`, `€50 gbp`, `£20 to usd`, `¥1000 usd`
- `100 usd` with the default target
- decimals (`12.5 usd eur`), any letter case, and the names dollar/dollars, euro/euros, pound/pounds, and yen

Recognized codes are the currencies Frankfurter currently publishes. Anything that is not a
conversion, including math expressions such as `2+2`, returns nil so the action hides itself.

Rates come from the Frankfurter v1 API at `https://api.frankfurter.app/latest` (no API key, ECB
reference rates). The host redirects to `api.frankfurter.dev`; the client follows that redirect.
A successful response is cached on disk for 12 hours. When a refresh fails, the client returns the
last cached table and reports the ECB date those rates came from.

The request sends only the base currency code. Amounts stay on device. Frankfurter does not require
an account, and its public instance does not log request URLs. The extension stores one JSON file
per base currency in `~/Library/Application Support/Tuna/CurrencyExtension`.

## Install from this checkout

From the repository root, on a Mac with Xcode and Tuna 0.110:

```bash
./scripts/tuna-extension install --scheme CurrencyExtension --restart
```

The project ad-hoc signs (`CODE_SIGN_IDENTITY = -`), so this does not need an Apple Developer team.
The script builds the host architecture, copies `CurrencyExtension.framework` to
`~/Library/Application Support/Tuna/ExtensionsDev`, and restarts Tuna. A code change needs that
restart; a rescan only reloads catalog data. If the extension does not appear, check
Settings → Sources and `./scripts/tuna-extension logs --last 20m`.

## Import a built framework

Tuna's manual install has two pickers. Their prompts, from the current Tuna app, are:

- **Import file:** "Select a .tunaextension, .bundle, .framework, or a directory with exactly one."
- **Import directory:** "Select a .framework/.bundle or a directory containing exactly one."

Both accept this extension's `CurrencyExtension.framework`. A `.tunaextension` is the store archive
(`Payload/` plus `tunaextension.json`); packaging that archive needs a Tuna binary to dump the
declaration, and the store path also checks a store signature. The manual framework import does not.
Tuna then asks you to confirm, because a file installed from disk is not verified by the store.

On Tuna 0.110 the store is Settings → Sources → Get More….

The Currency GitHub Actions workflow is manual (`workflow_dispatch` only, not a pull-request check).
It runs on `macos-26-intel`, tests CurrencyCore, and builds a universal Release framework
(arm64 and x86_64) with an ad-hoc signature. The deployment target stays macOS 15. The
`CurrencyExtension` artifact is `CurrencyExtension.framework.zip`, made with `ditto` so the
framework symlinks survive.

1. Run the Currency workflow on the branch you want and download the `CurrencyExtension` artifact.
2. Unzip GitHub's download. Inside is `CurrencyExtension.framework.zip`.
3. Unpack that second archive and clear the quarantine attribute Gatekeeper adds to the download:

```bash
ditto -x -k CurrencyExtension.framework.zip ~/Downloads
xattr -dr com.apple.quarantine ~/Downloads/CurrencyExtension.framework
```

4. In Tuna 0.110, open Settings → Sources → Get More….
5. Use import file and choose `CurrencyExtension.framework`, or use import directory and choose
   either that framework or a folder whose only bundle is that framework.
6. Confirm the install. Restart Tuna if the extension is installed but not loaded.

## Build

```bash
xcodebuild build \
  -project CurrencyExtension/CurrencyExtension.xcodeproj \
  -scheme CurrencyExtension \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM=
```

This fork only contains CurrencyExtension. `make` builds this scheme.
