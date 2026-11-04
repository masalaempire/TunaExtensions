import Foundation

/// A parsed conversion request. `targets` always contains at least one currency:
/// either the currencies written in the text, or `defaultTarget` when none were.
public struct CurrencyQuery: Equatable, Sendable {
  public let amount: Decimal
  public let source: CurrencyCode
  public let targets: [CurrencyCode]

  public init(amount: Decimal, source: CurrencyCode, targets: [CurrencyCode]) {
    self.amount = amount
    self.source = source
    self.targets = targets
  }
}

/// Parses amount + source currency + optional targets. Returns nil when the text
/// is not a conversion, including math expressions, so an action can hide itself.
public enum CurrencyParser {
  public static func parse(_ text: String, defaultTarget: String) -> CurrencyQuery? {
    guard text.allSatisfy(isAllowedCharacter) else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    var scanner = Scanner(text: trimmed)
    scanner.skipWhitespace()

    let symbolSource: CurrencyCode?
    if let character = scanner.peek(), let code = CurrencyCode.symbolCodes[character] {
      scanner.advance()
      symbolSource = CurrencyCode(validated: code)
    } else {
      symbolSource = nil
    }

    scanner.skipWhitespace()
    guard
      let amountText = scanner.readNumber(),
      let amount = DecimalFormat.decimal(from: amountText)
    else {
      return nil
    }

    let source: CurrencyCode
    if let symbolSource {
      source = symbolSource
    } else {
      scanner.skipWhitespace()
      guard
        let word = scanner.readWord(),
        let code = CurrencyCode.normalizeToken(word)
      else {
        return nil
      }
      source = CurrencyCode(validated: code)
    }

    scanner.skipSeparators()
    let checkpoint = scanner.index
    var usedConnector = false
    if let word = scanner.readWord() {
      let lowered = word.lowercased()
      if lowered == "to" || lowered == "in" {
        usedConnector = true
      } else {
        scanner.index = checkpoint
      }
    }

    var targets: [CurrencyCode] = []
    while !scanner.isAtEnd {
      scanner.skipSeparators()
      if scanner.isAtEnd { break }
      guard
        let word = scanner.readWord(),
        let code = CurrencyCode.normalizeToken(word)
      else {
        return nil
      }
      targets.append(CurrencyCode(validated: code))
      scanner.skipSeparators()
    }

    if targets.isEmpty {
      guard !usedConnector, let fallback = CurrencyCode(parsing: defaultTarget) else {
        return nil
      }
      targets = [fallback]
    }

    return CurrencyQuery(amount: amount, source: source, targets: targets)
  }

  private static func isAllowedCharacter(_ character: Character) -> Bool {
    switch character {
    case "$", "€", "£", "¥", ",", ".", " ", "\t", "\n", "\r":
      return true
    default:
      guard let ascii = character.asciiValue else { return false }
      let isDigit = ascii >= 48 && ascii <= 57
      let isLetter = (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
      return isDigit || isLetter
    }
  }
}

private struct Scanner {
  let text: String
  var index: String.Index

  init(text: String) {
    self.text = text
    self.index = text.startIndex
  }

  var isAtEnd: Bool { index == text.endIndex }

  mutating func skipWhitespace() {
    while let character = peek(), character == " " || character == "\t" || character == "\n" || character == "\r" {
      advance()
    }
  }

  mutating func skipSeparators() {
    while let character = peek(), character == " " || character == "\t" || character == "\n" || character == "\r" || character == "," {
      advance()
    }
  }

  func peek() -> Character? {
    isAtEnd ? nil : text[index]
  }

  func peekNext() -> Character? {
    guard let next = text.index(index, offsetBy: 1, limitedBy: text.endIndex), next < text.endIndex else {
      return nil
    }
    return text[next]
  }

  mutating func advance() {
    guard !isAtEnd else { return }
    index = text.index(after: index)
  }

  mutating func readNumber() -> String? {
    guard let first = peek(), isDigit(first) else { return nil }
    let start = index
    while let character = peek(), isDigit(character) {
      advance()
    }
    if peek() == ".", let next = peekNext(), isDigit(next) {
      advance()
      while let character = peek(), isDigit(character) {
        advance()
      }
    }
    return String(text[start..<index])
  }

  mutating func readWord() -> String? {
    guard let first = peek(), isLetter(first) else { return nil }
    let start = index
    while let character = peek(), isLetter(character) {
      advance()
    }
    return String(text[start..<index])
  }

  private func isDigit(_ character: Character) -> Bool {
    guard let ascii = character.asciiValue else { return false }
    return ascii >= 48 && ascii <= 57
  }

  private func isLetter(_ character: Character) -> Bool {
    guard let ascii = character.asciiValue else { return false }
    return (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
  }
}
