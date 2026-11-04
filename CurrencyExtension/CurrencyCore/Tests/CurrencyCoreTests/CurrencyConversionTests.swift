import XCTest
@testable import CurrencyCore

final class CurrencyConversionTests: XCTestCase {
  func testEuroAmountUsesSymbolAndTwoDecimals() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "100", source: "USD", targets: ["EUR"]),
      table: table(base: "USD", date: "2026-11-03", rates: ["EUR": "0.924"], origin: .network)
    )
    XCTAssertEqual(plan.missingTargets, [])
    XCTAssertEqual(plan.lines.count, 1)
    XCTAssertEqual(plan.lines[0].title, "€92.40")
    XCTAssertEqual(plan.lines[0].copyText, "€92.40")
    XCTAssertEqual(plan.lines[0].amount, DecimalFormat.decimal(from: "92.40"))
    XCTAssertEqual(plan.lines[0].detail, "ECB rate 2026-11-03")
  }

  func testSymbolsAndCodes() {
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("12.5"), currency: code("USD")),
      "$12.50"
    )
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("20"), currency: code("GBP")),
      "£20.00"
    )
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("149250"), currency: code("JPY")),
      "¥149,250"
    )
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("1234.5"), currency: code("CHF")),
      "1,234.50 CHF"
    )
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("10"), currency: code("KRW")),
      "10 KRW"
    )
    XCTAssertEqual(
      CurrencyConversion.formatted(amount: decimal("1000"), currency: code("KRW")),
      "1,000 KRW"
    )
  }

  func testYenDropsFractionDigits() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "10", source: "USD", targets: ["JPY"]),
      table: table(base: "USD", date: "2026-11-03", rates: ["JPY": "149.6"], origin: .cache)
    )
    XCTAssertEqual(plan.lines[0].title, "¥1,496")
    XCTAssertEqual(plan.lines[0].detail, "ECB rate 2026-11-03")
  }

  func testGroupsThousands() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "1000", source: "USD", targets: ["EUR"]),
      table: table(base: "USD", date: "2026-11-03", rates: ["EUR": "0.5"], origin: .network)
    )
    XCTAssertEqual(plan.lines[0].title, "€500.00")
    let large = CurrencyConversion.plan(
      for: query(amount: "2500", source: "EUR", targets: ["USD"]),
      table: table(base: "EUR", date: "2026-11-03", rates: ["USD": "1.2"], origin: .network)
    )
    XCTAssertEqual(large.lines[0].title, "$3,000.00")
  }

  func testSameCurrencyDoesNotNeedARate() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "100", source: "EUR", targets: ["EUR"]),
      table: table(base: "EUR", date: "2026-11-03", rates: ["USD": "1.1"], origin: .network)
    )
    XCTAssertEqual(plan.lines.map(\.title), ["€100.00"])
    XCTAssertEqual(plan.missingTargets, [])
  }

  func testOneLinePerTargetInOrder() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "100", source: "USD", targets: ["EUR", "GBP"]),
      table: table(base: "USD", date: "2026-11-03", rates: ["EUR": "0.5", "GBP": "0.25"], origin: .network)
    )
    XCTAssertEqual(plan.lines.map(\.target.rawValue), ["EUR", "GBP"])
    XCTAssertEqual(plan.lines.map(\.title), ["€50.00", "£25.00"])
    XCTAssertEqual(plan.lines.map(\.copyText), plan.lines.map(\.title))
  }

  func testMissingRateIsReportedAndSkipped() {
    let plan = CurrencyConversion.plan(
      for: query(amount: "100", source: "USD", targets: ["EUR", "AUD"]),
      table: table(base: "USD", date: "2026-11-03", rates: ["EUR": "0.5"], origin: .network)
    )
    XCTAssertEqual(plan.lines.map(\.title), ["€50.00"])
    XCTAssertEqual(plan.missingTargets.map(\.rawValue), ["AUD"])
    XCTAssertEqual(
      CurrencyConversion.missingRatesMessage(targets: plan.missingTargets),
      "No exchange rate is available for AUD."
    )
    XCTAssertEqual(
      CurrencyConversion.missingRatesMessage(targets: [code("AUD"), code("CAD")]),
      "No exchange rate is available for AUD or CAD."
    )
  }

  func testOfflineDetailNamesTheCachedDate() {
    let offline = table(base: "USD", date: "2024-01-15", rates: ["EUR": "0.9"], origin: .offlineCache)
    XCTAssertEqual(CurrencyConversion.rateDetail(for: offline), "Offline rates from 2024-01-15")
    let plan = CurrencyConversion.plan(
      for: query(amount: "10", source: "USD", targets: ["EUR"]),
      table: offline
    )
    XCTAssertEqual(plan.lines[0].detail, "Offline rates from 2024-01-15")
    XCTAssertEqual(plan.lines[0].title, "€9.00")

    let fresh = table(base: "USD", date: "2026-11-03", rates: ["EUR": "0.9"], origin: .cache)
    XCTAssertEqual(CurrencyConversion.rateDetail(for: fresh), "ECB rate 2026-11-03")
    XCTAssertFalse(CurrencyConversion.rateDetail(for: fresh).contains("Offline"))
  }

  func testInlineErrorWhenNothingIsCached() {
    XCTAssertEqual(
      CurrencyRatesError.offlineUnavailable.inlineMessage,
      "Couldn't fetch exchange rates, and there's no saved rate to use."
    )
    XCTAssertEqual(
      CurrencyRatesError.httpStatus(503).inlineMessage,
      "Frankfurter returned HTTP 503, and there's no saved rate to use."
    )
    XCTAssertEqual(
      CurrencyRatesError.invalidResponse.inlineMessage,
      "Frankfurter returned a response that couldn't be read, and there's no saved rate to use."
    )
  }

  private func query(amount: String, source: String, targets: [String]) -> CurrencyQuery {
    CurrencyQuery(
      amount: decimal(amount),
      source: code(source),
      targets: targets.map(code)
    )
  }

  private func table(
    base: String,
    date: String,
    rates: [String: String],
    origin: ExchangeRateOrigin
  ) -> ExchangeRateTable {
    ExchangeRateTable(
      base: base,
      rateDate: date,
      rates: rates.mapValues(decimal),
      fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
      origin: origin
    )
  }

  private func decimal(_ text: String) -> Decimal {
    DecimalFormat.decimal(from: text)!
  }

  private func code(_ text: String) -> CurrencyCode {
    CurrencyCode(parsing: text)!
  }
}
