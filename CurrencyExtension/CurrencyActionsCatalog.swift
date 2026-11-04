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

  /// Stub only. The next change wires this to CurrencyCore.
  private static func makeConvertCurrencyAction() -> CatalogAction {
    let action = CatalogAction(
      id: "convert-currency",
      title: "Convert Currency",
      type: .action
    ) { _, _ in
      .failure("Currency conversion is not implemented yet.")
    }
    action.systemSymbolName = "coloncurrencysign"
    action.supportedSubjectTypes = [.textSnippet]
    return action
  }
}
