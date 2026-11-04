# Changelog

## 0.2

- Convert Currency parses the typed text snippet and returns one copyable amount per target currency.
- Add a default target currency setting, EUR unless changed.
- Show the ECB rate date, and say when that date came from the offline cache.
- Show an inline error when rates cannot be fetched and no cache exists.
- Ad-hoc sign the extension so it can be installed without an Apple Developer team.

## 0.1

- Add the Currency extension skeleton for Tuna 0.80 / TunaKit 1.14.0.
- Add CurrencyCore: a conversion parser and a Frankfurter rates client with a 12-hour disk cache and offline fallback.
