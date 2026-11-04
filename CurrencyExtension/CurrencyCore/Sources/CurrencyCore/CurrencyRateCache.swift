import Foundation

public struct CachedExchangeRates: Equatable, Sendable {
  public let base: String
  public let rateDate: String
  public let rates: [String: Decimal]
  public let fetchedAt: Date

  public init(base: String, rateDate: String, rates: [String: Decimal], fetchedAt: Date) {
    self.base = base
    self.rateDate = rateDate
    self.rates = rates
    self.fetchedAt = fetchedAt
  }
}

public protocol CurrencyRateCache: Sendable {
  func load(base: String) throws -> CachedExchangeRates?
  func save(_ rates: CachedExchangeRates) throws
}

/// JSON cache of the last Frankfurter table for each base currency.
public struct FileCurrencyRateCache: CurrencyRateCache {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  public func load(base: String) throws -> CachedExchangeRates? {
    let url = fileURL(for: base)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      return nil
    }
    guard let stored = try? decoder.decode(StoredRates.self, from: data) else { return nil }
    guard stored.base == base else { return nil }
    var rates: [String: Decimal] = [:]
    for (code, text) in stored.rates {
      guard let value = DecimalFormat.decimal(from: text) else { return nil }
      rates[code] = value
    }
    return CachedExchangeRates(
      base: stored.base,
      rateDate: stored.rateDate,
      rates: rates,
      fetchedAt: stored.fetchedAt
    )
  }

  public func save(_ rates: CachedExchangeRates) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let stored = StoredRates(
      base: rates.base,
      rateDate: rates.rateDate,
      fetchedAt: rates.fetchedAt,
      rates: rates.rates.mapValues(DecimalFormat.string(from:))
    )
    let data = try encoder.encode(stored)
    try data.write(to: fileURL(for: rates.base), options: .atomic)
  }

  private func fileURL(for base: String) -> URL {
    directory.appendingPathComponent("frankfurter-\(base).json")
  }

  private var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

private struct StoredRates: Codable {
  let base: String
  let rateDate: String
  let fetchedAt: Date
  let rates: [String: String]
}
