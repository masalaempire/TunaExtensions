import CurrencyCore
import Foundation
import TunaKit

@MainActor
public final class CurrencyActionsCatalog: ActionCatalog {
  public let identifier: String
  public let name: String
  public private(set) var actions: [CatalogAction]

  public required init(definition: ActionCatalogDefinition) {
    identifier = definition.identifier
    name = definition.name
    actions = [Self.makeConvertCurrencyAction()]
  }

  private static func makeConvertCurrencyAction() -> CatalogAction {
    let action = PredicateAwareAction(id: "convert-currency", title: "Convert Currency") { subject, _ in
      await CurrencyActionRunner.result(for: subject)
    }
    action.systemSymbolName = "coloncurrencysign"
    action.supportedSubjectTypes = [.textSnippet]
    action.executionPolicy = .keepVisible
    action.subjectPredicate = { subject in
      guard let text = subject?.textInputValue(), !text.isEmpty else { return false }
      return CurrencyParser.parse(text, defaultTarget: CurrencySettings.defaultTargetText()) != nil
    }
    return action
  }
}

enum CurrencyActionRunner {
  static func result(for subject: CatalogItem) async -> ActionResult {
    guard let text = subject.textInputValue(), !text.isEmpty else {
      return .failure("Type an amount and a currency, such as 100 usd eur.")
    }
    guard let query = CurrencyParser.parse(text, defaultTarget: CurrencySettings.defaultTargetText()) else {
      return .failure("That text is not a currency conversion.")
    }
    return await fetch(query)
  }

  private static func fetch(_ query: CurrencyQuery) async -> ActionResult {
    do {
      let table = try await client.latestRates(base: query.source.rawValue)
      let plan = CurrencyConversion.plan(for: query, table: table)
      guard !plan.lines.isEmpty else {
        return .failure(CurrencyConversion.missingRatesMessage(targets: plan.missingTargets))
      }
      let items = plan.lines.enumerated().map { index, line in
        CurrencyAmountItem(line: line, index: index)
      }
      return .results(items)
    } catch let error as CurrencyRatesError {
      return .failure(error.inlineMessage)
    } catch {
      return .failure(CurrencyRatesError.offlineUnavailable.inlineMessage)
    }
  }

  private static let client: FrankfurterRatesClient = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 12
    configuration.timeoutIntervalForResource = 15
    configuration.waitsForConnectivity = false
    let transport = URLSessionCurrencyTransport(session: URLSession(configuration: configuration))
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let directory = base.appendingPathComponent("Tuna/CurrencyExtension", isDirectory: true)
    return FrankfurterRatesClient(transport: transport, cache: FileCurrencyRateCache(directory: directory))
  }()
}

final class CurrencyAmountItem: CatalogItem, TextValueProviding, CopyRepresentationProviding, @unchecked Sendable {
  let textValue: String
  let copyRepresentation: String?
  private let detailText: String
  private let keys: [String]

  init(line: CurrencyConversionLine, index: Int) {
    textValue = line.copyText
    copyRepresentation = line.copyText
    detailText = line.detail
    keys = [line.copyText, line.target.rawValue]
    super.init(
      id: "currency:\(index):\(line.target.rawValue):\(line.copyText)",
      title: line.title,
      type: .entity
    )
    typeID = .textSnippet
  }

  override var detail: String? { detailText }
  override var searchKeys: [String] { keys }
}
