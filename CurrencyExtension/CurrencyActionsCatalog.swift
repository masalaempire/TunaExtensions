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
    let action = PredicateAwareAction(
      id: "convert-currency",
      title: "Convert Currency",
      type: .action
    ) { subject, _ in
      CurrencyActionRunner.result(for: subject)
    }
    action.systemSymbolName = "coloncurrencysign"
    action.supportedSubjectTypes = [.textSnippet]
    action.producesInlineResult = true
    action.commitStyleDependsOnResult = true
    action.subjectPredicate = { subject in
      guard let text = (subject as? TextSnippetItem)?.text else { return false }
      return CurrencyParser.parse(text, defaultTarget: CurrencySettings.defaultTargetText()) != nil
    }
    return action
  }
}

/// TunaKit 1.14 action callbacks are synchronous. The rate fetch finishes before this returns,
/// so the callback can hand back the result list or the inline error.
enum CurrencyActionRunner {
  static func result(for subject: CatalogItem) -> ActionResult {
    guard let text = (subject as? TextSnippetItem)?.text else {
      return .failure("Type an amount and a currency, such as 100 usd eur.")
    }
    guard let query = CurrencyParser.parse(text, defaultTarget: CurrencySettings.defaultTargetText()) else {
      return .failure("That text is not a currency conversion.")
    }

    let box = ResultBox()
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached(priority: .userInitiated) {
      box.result = await fetch(query)
      semaphore.signal()
    }
    semaphore.wait()
    return box.result ?? .failure(CurrencyRatesError.offlineUnavailable.inlineMessage)
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

private final class ResultBox: @unchecked Sendable {
  var result: ActionResult?
}

final class CurrencyAmountItem: CatalogItem, TextValueProviding, CopyRepresentationProviding, @unchecked Sendable {
  let textValue: String
  let copyRepresentation: String?
  private let detailText: String
  private let searchTextValue: String

  init(line: CurrencyConversionLine, index: Int) {
    textValue = line.copyText
    copyRepresentation = line.copyText
    detailText = line.detail
    searchTextValue = "\(line.copyText) \(line.target.rawValue)"
    super.init(
      id: "currency:\(index):\(line.target.rawValue):\(line.copyText)",
      title: line.title,
      type: .entity
    )
    typeID = .textSnippet
  }

  override var detail: String? { detailText }
  override var searchText: String { searchTextValue }
}
