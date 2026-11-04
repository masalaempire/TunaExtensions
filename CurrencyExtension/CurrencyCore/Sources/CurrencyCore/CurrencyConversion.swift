import Foundation

/// One converted amount ready for a result row. `title` and `copyText` are the
/// same string, such as `€92.40`, so Copy and Paste use what the row shows.
public struct CurrencyConversionLine: Equatable, Sendable {
  public let target: CurrencyCode
  public let amount: Decimal
  public let title: String
  public let copyText: String
  public let detail: String

  public init(target: CurrencyCode, amount: Decimal, title: String, copyText: String, detail: String) {
    self.target = target
    self.amount = amount
    self.title = title
    self.copyText = copyText
    self.detail = detail
  }
}

/// Quotes for every target that the table can price, plus any targets it cannot.
public struct CurrencyConversionPlan: Equatable, Sendable {
  public let lines: [CurrencyConversionLine]
  public let missingTargets: [CurrencyCode]

  public init(lines: [CurrencyConversionLine], missingTargets: [CurrencyCode]) {
    self.lines = lines
    self.missingTargets = missingTargets
  }
}

public enum CurrencyConversion {
  public static func plan(for query: CurrencyQuery, table: ExchangeRateTable) -> CurrencyConversionPlan {
    let detail = rateDetail(for: table)
    var lines: [CurrencyConversionLine] = []
    var missing: [CurrencyCode] = []
    for target in query.targets {
      guard let rate = rate(for: target, table: table, source: query.source) else {
        missing.append(target)
        continue
      }
      let amount = rounded(query.amount * rate, fractionDigits: fractionDigits(for: target))
      let title = formatted(amount: amount, currency: target)
      lines.append(CurrencyConversionLine(
        target: target,
        amount: amount,
        title: title,
        copyText: title,
        detail: detail
      ))
    }
    return CurrencyConversionPlan(lines: lines, missingTargets: missing)
  }

  /// Always names the ECB date. Offline fallback says the rates were not fetched today.
  public static func rateDetail(for table: ExchangeRateTable) -> String {
    if table.usedOfflineCache {
      return "Offline rates from \(table.rateDate)"
    }
    return "ECB rate \(table.rateDate)"
  }

  public static func missingRatesMessage(targets: [CurrencyCode]) -> String {
    let codes = targets.map(\.rawValue)
    switch codes.count {
    case 0:
      return "No exchange rate is available."
    case 1:
      return "No exchange rate is available for \(codes[0])."
    default:
      let head = codes.dropLast().joined(separator: ", ")
      return "No exchange rate is available for \(head) or \(codes[codes.count - 1])."
    }
  }

  public static func formatted(amount: Decimal, currency: CurrencyCode) -> String {
    let number = formatNumber(amount, fractionDigits: fractionDigits(for: currency))
    if let symbol = symbols[currency.rawValue] {
      return symbol + number
    }
    return "\(number) \(currency.rawValue)"
  }

  private static let symbols = [
    "USD": "$",
    "EUR": "€",
    "GBP": "£",
    "JPY": "¥",
  ]

  private static func fractionDigits(for currency: CurrencyCode) -> Int {
    switch currency.rawValue {
    case "JPY", "KRW", "ISK":
      return 0
    default:
      return 2
    }
  }

  private static func rate(for target: CurrencyCode, table: ExchangeRateTable, source: CurrencyCode) -> Decimal? {
    if target == source {
      return 1
    }
    return table.rates[target.rawValue]
  }

  private static func rounded(_ value: Decimal, fractionDigits: Int) -> Decimal {
    var source = value
    var result = Decimal()
    NSDecimalRound(&result, &source, fractionDigits, .plain)
    return result
  }

  private static func formatNumber(_ value: Decimal, fractionDigits: Int) -> String {
    let plain = DecimalFormat.string(from: value)
    let negative = plain.hasPrefix("-")
    let body = negative ? String(plain.dropFirst()) : plain
    let parts = body.split(separator: ".", omittingEmptySubsequences: false)
    var whole = parts.isEmpty ? "0" : String(parts[0])
    if whole.isEmpty { whole = "0" }
    var fraction = parts.count > 1 ? String(parts[1]) : ""
    if fraction.count > fractionDigits {
      fraction = String(fraction.prefix(fractionDigits))
    }
    if fractionDigits > 0 {
      while fraction.count < fractionDigits {
        fraction.append("0")
      }
    } else {
      fraction = ""
    }

    var grouped = ""
    for (offset, character) in whole.reversed().enumerated() {
      if offset > 0, offset.isMultiple(of: 3) {
        grouped.append(",")
      }
      grouped.append(character)
    }
    let wholeText = String(grouped.reversed())
    let number = fractionDigits == 0 ? wholeText : "\(wholeText).\(fraction)"
    return negative ? "-\(number)" : number
  }
}

extension CurrencyRatesError {
  /// Shown in the action result when Frankfurter cannot be used and no cache exists.
  public var inlineMessage: String {
    switch self {
    case .offlineUnavailable:
      return "Couldn't fetch exchange rates, and there's no saved rate to use."
    case .invalidCurrencyCode:
      return "That currency is not recognized."
    case .httpStatus(let status):
      return "Frankfurter returned HTTP \(status), and there's no saved rate to use."
    case .invalidResponse:
      return "Frankfurter returned a response that couldn't be read, and there's no saved rate to use."
    }
  }
}
