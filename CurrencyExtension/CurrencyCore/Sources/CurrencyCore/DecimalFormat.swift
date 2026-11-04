import Foundation

enum DecimalFormat {
  static let posix = Locale(identifier: "en_US_POSIX")

  static func decimal(from text: String) -> Decimal? {
    Decimal(string: text, locale: posix)
  }

  static func string(from value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.locale = posix
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 34
    formatter.decimalSeparator = "."
    return formatter.string(from: value as NSDecimalNumber) ?? "0"
  }
}
