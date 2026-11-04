import Foundation

/// An ISO 4217 code Frankfurter can quote, or a symbol/name that maps to one.
public struct CurrencyCode: Hashable, Sendable, Codable {
  public let rawValue: String

  public init?(parsing text: String) {
    guard let code = Self.normalize(text) else { return nil }
    rawValue = code
  }

  init(validated rawValue: String) {
    self.rawValue = rawValue
  }

  /// Currencies published by the Frankfurter v1 API (`/currencies`), which serves ECB rates.
  public static let knownCodes: Set<String> = [
    "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD",
    "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK",
    "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR",
  ]

  static let symbolCodes: [Character: String] = [
    "$": "USD",
    "€": "EUR",
    "£": "GBP",
    "¥": "JPY",
  ]

  private static let names: [String: String] = [
    "dollar": "USD",
    "dollars": "USD",
    "euro": "EUR",
    "euros": "EUR",
    "pound": "GBP",
    "pounds": "GBP",
    "yen": "JPY",
  ]

  static func normalize(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count == 1, let character = trimmed.first, let code = symbolCodes[character] {
      return code
    }
    return normalizeToken(trimmed)
  }

  static func normalizeToken(_ token: String) -> String? {
    let lowered = token.lowercased()
    if let named = names[lowered] {
      return named
    }
    let code = token.uppercased()
    guard code.count == 3, code.allSatisfy(\.isASCIILetter), knownCodes.contains(code) else {
      return nil
    }
    return code
  }
}

extension Character {
  fileprivate var isASCIILetter: Bool {
    guard let ascii = asciiValue else { return false }
    return (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
  }
}
