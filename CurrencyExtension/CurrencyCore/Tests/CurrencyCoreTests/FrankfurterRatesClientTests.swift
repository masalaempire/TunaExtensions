import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization
import XCTest
@testable import CurrencyCore

final class FrankfurterRatesClientTests: XCTestCase {
  func testFetchStoresRatesFromFrankfurter() async throws {
    let transport = ScriptedTransport { request in
      XCTAssertEqual(request.url?.host, "api.frankfurter.app")
      XCTAssertEqual(request.url?.path, "/latest")
      XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems, [
        URLQueryItem(name: "from", value: "USD")
      ])
      XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
      return CurrencyHTTPResponse(statusCode: 200, body: Data(Self.sampleJSON.utf8))
    }
    let directory = try makeCacheDirectory()
    let cache = FileCurrencyRateCache(directory: directory)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let client = FrankfurterRatesClient(transport: transport, cache: cache, now: { now })

    let table = try await client.latestRates(base: "usd")

    XCTAssertEqual(transport.callCount, 1)
    XCTAssertEqual(table.base, "USD")
    XCTAssertEqual(table.rateDate, "2026-11-03")
    XCTAssertEqual(table.rates["EUR"], DecimalFormat.decimal(from: "0.5"))
    XCTAssertEqual(table.rates["GBP"], DecimalFormat.decimal(from: "2"))
    XCTAssertEqual(table.fetchedAt, now)
    XCTAssertEqual(table.origin, .network)
    XCTAssertFalse(table.usedOfflineCache)

    let stored = try XCTUnwrap(cache.load(base: "USD"))
    XCTAssertEqual(stored.rateDate, "2026-11-03")
    XCTAssertEqual(stored.fetchedAt, now)
    XCTAssertEqual(stored.rates["EUR"], DecimalFormat.decimal(from: "0.5"))
  }

  func testCacheHitDoesNotFetch() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let cache = FileCurrencyRateCache(directory: try makeCacheDirectory())
    try cache.save(CachedExchangeRates(
      base: "USD",
      rateDate: "2024-06-01",
      rates: ["EUR": try XCTUnwrap(DecimalFormat.decimal(from: "0.25"))],
      fetchedAt: now.addingTimeInterval(-(11 * 60 * 60))
    ))
    let transport = ScriptedTransport { _ in
      XCTFail("fresh cache should not call the network")
      throw URLError(.notConnectedToInternet)
    }
    let client = FrankfurterRatesClient(transport: transport, cache: cache, now: { now })

    let table = try await client.latestRates(base: "USD")

    XCTAssertEqual(transport.callCount, 0)
    XCTAssertEqual(table.origin, .cache)
    XCTAssertEqual(table.rateDate, "2024-06-01")
    XCTAssertEqual(table.rates["EUR"], DecimalFormat.decimal(from: "0.25"))
    XCTAssertFalse(table.usedOfflineCache)
  }

  func testExpiredCacheFetchesAgain() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let cache = FileCurrencyRateCache(directory: try makeCacheDirectory())
    try cache.save(CachedExchangeRates(
      base: "USD",
      rateDate: "2024-01-01",
      rates: ["EUR": try XCTUnwrap(DecimalFormat.decimal(from: "0.25"))],
      fetchedAt: now.addingTimeInterval(-FrankfurterRatesClient.cacheLifetime)
    ))
    let transport = ScriptedTransport { _ in
      CurrencyHTTPResponse(statusCode: 200, body: Data(Self.sampleJSON.utf8))
    }
    let client = FrankfurterRatesClient(transport: transport, cache: cache, now: { now })

    let table = try await client.latestRates(base: "USD")

    XCTAssertEqual(transport.callCount, 1)
    XCTAssertEqual(table.origin, .network)
    XCTAssertEqual(table.rateDate, "2026-11-03")
    XCTAssertEqual(table.rates["EUR"], DecimalFormat.decimal(from: "0.5"))
    let stored = try XCTUnwrap(cache.load(base: "USD"))
    XCTAssertEqual(stored.rateDate, "2026-11-03")
    XCTAssertEqual(stored.fetchedAt, now)
  }

  func testOfflineFallbackUsesLastCachedRateDate() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let cache = FileCurrencyRateCache(directory: try makeCacheDirectory())
    try cache.save(CachedExchangeRates(
      base: "EUR",
      rateDate: "2024-01-15",
      rates: ["USD": try XCTUnwrap(DecimalFormat.decimal(from: "1.25"))],
      fetchedAt: now.addingTimeInterval(-(48 * 60 * 60))
    ))
    let transport = ScriptedTransport { _ in
      throw URLError(.notConnectedToInternet)
    }
    let client = FrankfurterRatesClient(transport: transport, cache: cache, now: { now })

    let table = try await client.latestRates(base: "eur")

    XCTAssertEqual(transport.callCount, 1)
    XCTAssertEqual(table.origin, .offlineCache)
    XCTAssertTrue(table.usedOfflineCache)
    XCTAssertEqual(table.base, "EUR")
    XCTAssertEqual(table.rateDate, "2024-01-15")
    XCTAssertEqual(table.rates["USD"], DecimalFormat.decimal(from: "1.25"))
    XCTAssertEqual(table.fetchedAt, now.addingTimeInterval(-(48 * 60 * 60)))
  }

  func testOfflineWithoutCacheThrows() async {
    let cache = FileCurrencyRateCache(directory: URL(fileURLWithPath: "/tmp/currency-core-missing-\(UUID().uuidString)"))
    let transport = ScriptedTransport { _ in
      throw URLError(.notConnectedToInternet)
    }
    let client = FrankfurterRatesClient(transport: transport, cache: cache, now: { Date() })

    do {
      _ = try await client.latestRates(base: "USD")
      XCTFail("expected offline failure")
    } catch CurrencyRatesError.offlineUnavailable {
    } catch {
      XCTFail("unexpected error: \(error)")
    }
  }

  private static let sampleJSON = """
  {"amount":1.0,"base":"USD","date":"2026-11-03","rates":{"EUR":0.5,"GBP":2}}
  """

  private func makeCacheDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "currency-core-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}

private final class ScriptedTransport: CurrencyHTTPTransport, @unchecked Sendable {
  private let requests = Mutex(0)
  private let handler: @Sendable (URLRequest) throws -> CurrencyHTTPResponse

  init(handler: @escaping @Sendable (URLRequest) throws -> CurrencyHTTPResponse) {
    self.handler = handler
  }

  var callCount: Int {
    requests.withLock { $0 }
  }

  func data(for request: URLRequest) async throws -> CurrencyHTTPResponse {
    requests.withLock { $0 += 1 }
    return try handler(request)
  }
}
