import XCTest
@testable import CurrencyCore

final class CurrencyParserTests: XCTestCase {
  func testAmountGluedToSourceCode() {
    assertQuery("100usd eur", amount: "100", source: "USD", targets: ["EUR"])
  }

  func testAmountSeparatedFromSourceAndTarget() {
    assertQuery("100 usd eur", amount: "100", source: "USD", targets: ["EUR"])
  }

  func testToConnector() {
    assertQuery("100 usd to eur", amount: "100", source: "USD", targets: ["EUR"])
  }

  func testInConnector() {
    assertQuery("100 usd in eur", amount: "100", source: "USD", targets: ["EUR"])
  }

  func testDollarSymbolInYen() {
    assertQuery("$100 in yen", amount: "100", source: "USD", targets: ["JPY"])
  }

  func testEuroSymbolToPoundCode() {
    assertQuery("€50 gbp", amount: "50", source: "EUR", targets: ["GBP"])
  }

  func testPoundSymbolToDollarCode() {
    assertQuery("£20 to usd", amount: "20", source: "GBP", targets: ["USD"])
  }

  func testYenSymbolToDollarCode() {
    assertQuery("¥1000 usd", amount: "1000", source: "JPY", targets: ["USD"])
  }

  func testMissingTargetUsesDefault() {
    assertQuery("100 usd", amount: "100", source: "USD", targets: ["EUR"], defaultTarget: "EUR")
    assertQuery("100 usd", amount: "100", source: "USD", targets: ["GBP"], defaultTarget: "gbp")
    assertQuery("$100", amount: "100", source: "USD", targets: ["JPY"], defaultTarget: "yen")
  }

  func testDecimalAmount() {
    assertQuery("12.5 usd eur", amount: "12.5", source: "USD", targets: ["EUR"])
  }

  func testISOCodesAreCaseInsensitive() {
    assertQuery("100 UsD eUr", amount: "100", source: "USD", targets: ["EUR"])
    assertQuery("10 DKK in usd", amount: "10", source: "DKK", targets: ["USD"])
  }

  func testCommonCurrencyNames() {
    assertQuery("100 dollars to euros", amount: "100", source: "USD", targets: ["EUR"])
    assertQuery("100 dollar euros", amount: "100", source: "USD", targets: ["EUR"])
    assertQuery("50 pounds yen", amount: "50", source: "GBP", targets: ["JPY"])
    assertQuery("1 yen", amount: "1", source: "JPY", targets: ["USD"], defaultTarget: "dollars")
  }

  func testExplicitTargetsIgnoreDefault() {
    assertQuery("100 usd eur", amount: "100", source: "USD", targets: ["EUR"], defaultTarget: "GBP")
  }

  func testMultipleTargets() {
    assertQuery("100 usd eur gbp", amount: "100", source: "USD", targets: ["EUR", "GBP"])
    assertQuery("100 usd to eur, gbp", amount: "100", source: "USD", targets: ["EUR", "GBP"])
  }

  func testExtraWhitespace() {
    assertQuery("  100   usd   to   eur  ", amount: "100", source: "USD", targets: ["EUR"])
  }

  func testRejectsTextThatIsNotAConversion() {
    let rejected = [
      "",
      "   ",
      "hello",
      "2+2",
      "100+5 usd",
      "100 * 2 usd",
      "sqrt(9)",
      "100",
      "usd eur",
      "100 usd to",
      "100 usd in",
      "usd 100 eur",
      "convert 100 usd eur",
      "100 usd xyz",
      "100 the cat",
      "100 usd to eur please",
    ]
    for text in rejected {
      XCTAssertNil(CurrencyParser.parse(text, defaultTarget: "EUR"), text)
    }
    XCTAssertNil(CurrencyParser.parse("100 usd", defaultTarget: "xyz"))
    XCTAssertNil(CurrencyParser.parse("100 usd", defaultTarget: ""))
  }

  private func assertQuery(
    _ text: String,
    amount: String,
    source: String,
    targets: [String],
    defaultTarget: String = "EUR",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let query = CurrencyParser.parse(text, defaultTarget: defaultTarget)
    XCTAssertEqual(query?.amount, DecimalFormat.decimal(from: amount), file: file, line: line)
    XCTAssertEqual(query?.source.rawValue, source, file: file, line: line)
    XCTAssertEqual(query?.targets.map(\.rawValue), targets, file: file, line: line)
  }
}
