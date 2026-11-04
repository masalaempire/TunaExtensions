import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct CurrencyHTTPResponse: Equatable, Sendable {
  public let statusCode: Int
  public let body: Data

  public init(statusCode: Int, body: Data) {
    self.statusCode = statusCode
    self.body = body
  }
}

public protocol CurrencyHTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> CurrencyHTTPResponse
}

public struct URLSessionCurrencyTransport: CurrencyHTTPTransport, @unchecked Sendable {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> CurrencyHTTPResponse {
    let (body, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw CurrencyRatesError.invalidResponse
    }
    return CurrencyHTTPResponse(statusCode: http.statusCode, body: body)
  }
}
