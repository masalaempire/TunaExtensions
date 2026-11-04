import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ExchangeRateOrigin: Equatable, Sendable {
  /// Fetched from Frankfurter during this call.
  case network
  /// Served from a cache that is still inside the 12-hour lifetime.
  case cache
  /// Network refresh failed. `rateDate` is the ECB date stored with the last table.
  case offlineCache
}

public struct ExchangeRateTable: Equatable, Sendable {
  public let base: String
  /// ECB reference date from the Frankfurter payload (`YYYY-MM-DD`), including when the table is an offline fallback.
  public let rateDate: String
  /// Quote-per-1-base rates. The base currency itself is not included.
  public let rates: [String: Decimal]
  public let fetchedAt: Date
  public let origin: ExchangeRateOrigin

  public init(
    base: String,
    rateDate: String,
    rates: [String: Decimal],
    fetchedAt: Date,
    origin: ExchangeRateOrigin
  ) {
    self.base = base
    self.rateDate = rateDate
    self.rates = rates
    self.fetchedAt = fetchedAt
    self.origin = origin
  }

  public var usedOfflineCache: Bool { origin == .offlineCache }
}

public enum CurrencyRatesError: Error, Equatable {
  case invalidCurrencyCode
  case invalidResponse
  case httpStatus(Int)
  case offlineUnavailable
}

/// Latest ECB rates from `https://api.frankfurter.app/latest`. That host redirects to the v1 API.
public struct FrankfurterRatesClient: Sendable {
  public static let latestRatesURL = URL(string: "https://api.frankfurter.app/latest")!
  public static let cacheLifetime: TimeInterval = 12 * 60 * 60

  private let transport: any CurrencyHTTPTransport
  private let cache: any CurrencyRateCache
  private let now: @Sendable () -> Date
  private let cacheLifetime: TimeInterval

  public init(
    transport: any CurrencyHTTPTransport,
    cache: any CurrencyRateCache,
    now: @escaping @Sendable () -> Date = { Date() },
    cacheLifetime: TimeInterval = FrankfurterRatesClient.cacheLifetime
  ) {
    self.transport = transport
    self.cache = cache
    self.now = now
    self.cacheLifetime = cacheLifetime
  }

  public func latestRates(base rawBase: String) async throws -> ExchangeRateTable {
    let base = rawBase.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard base.count == 3, base.allSatisfy(\.isASCIILetter) else {
      throw CurrencyRatesError.invalidCurrencyCode
    }

    let cached = try? cache.load(base: base)
    let fetchedAt = now()
    if let cached, fetchedAt.timeIntervalSince(cached.fetchedAt) < cacheLifetime {
      return table(from: cached, origin: .cache)
    }

    do {
      let response = try await transport.data(for: makeRequest(base: base))
      guard (200..<300).contains(response.statusCode) else {
        throw CurrencyRatesError.httpStatus(response.statusCode)
      }
      let parsed = try parseLatest(response.body, expectedBase: base)
      let stored = CachedExchangeRates(
        base: base,
        rateDate: parsed.rateDate,
        rates: parsed.rates,
        fetchedAt: fetchedAt
      )
      try? cache.save(stored)
      return table(from: stored, origin: .network)
    } catch let error as CurrencyRatesError {
      if let cached {
        return table(from: cached, origin: .offlineCache)
      }
      throw error
    } catch {
      if let cached {
        return table(from: cached, origin: .offlineCache)
      }
      throw CurrencyRatesError.offlineUnavailable
    }
  }

  private func makeRequest(base: String) -> URLRequest {
    var components = URLComponents(url: Self.latestRatesURL, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "from", value: base)]
    var request = URLRequest(url: components?.url ?? Self.latestRatesURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private func table(from cached: CachedExchangeRates, origin: ExchangeRateOrigin) -> ExchangeRateTable {
    ExchangeRateTable(
      base: cached.base,
      rateDate: cached.rateDate,
      rates: cached.rates,
      fetchedAt: cached.fetchedAt,
      origin: origin
    )
  }

  private func parseLatest(_ data: Data, expectedBase: String) throws -> (rateDate: String, rates: [String: Decimal]) {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw CurrencyRatesError.invalidResponse
    }
    guard let base = object["base"] as? String, base.uppercased() == expectedBase else {
      throw CurrencyRatesError.invalidResponse
    }
    guard let rateDate = object["date"] as? String, !rateDate.isEmpty else {
      throw CurrencyRatesError.invalidResponse
    }
    guard let rawRates = object["rates"] as? [String: Any] else {
      throw CurrencyRatesError.invalidResponse
    }

    var rates: [String: Decimal] = [:]
    for (code, value) in rawRates {
      let normalized = code.uppercased()
      guard normalized.count == 3, normalized.allSatisfy(\.isASCIILetter), let decimal = decimal(fromJSON: value) else {
        throw CurrencyRatesError.invalidResponse
      }
      rates[normalized] = decimal
    }
    return (rateDate, rates)
  }

  private func decimal(fromJSON value: Any) -> Decimal? {
    if value is Bool { return nil }
    if let text = value as? String {
      return DecimalFormat.decimal(from: text)
    }
    guard let number = value as? NSNumber else { return nil }
    let text = NSDecimalNumber(decimal: number.decimalValue).stringValue
    return DecimalFormat.decimal(from: text) ?? number.decimalValue
  }
}

extension Character {
  fileprivate var isASCIILetter: Bool {
    guard let ascii = asciiValue else { return false }
    return (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
  }
}
