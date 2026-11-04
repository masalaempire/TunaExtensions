import CurrencyCore
import Foundation
import TunaKit

@objc(CurrencyExtension)
public final class CurrencyExtension: Extension {
  public override var declaration: ExtensionDeclaration? {
    ExtensionDeclaration(
      metadata: ExtensionMetadata(
        displayName: "Currency",
        author: "masalaempire",
        description: "Convert amounts between currencies.",
        iconName: "coloncurrencysign"
      ),
      compatibility: ExtensionDeclarationCompatibility(
        minTuna: "0.110",
        minTunaKit: "1.22.0"
      ),
      settings: [CurrencySettings.defaultTarget],
      actionCatalogs: [
        ActionCatalogDeclaration(
          id: "currency.actions",
          type: CurrencyActionsCatalog.self,
          name: "Currency Actions"
        )
      ]
    )
  }
}

enum CurrencySettings {
  /// Action catalogs still cannot declare settings. This lives on the extension and shows
  /// on the Currency page in Settings → Sources.
  static let defaultTarget = CatalogSettingDefinition(
    key: "DefaultTargetCurrency",
    type: .string,
    label: "Default target currency",
    defaultValue: "EUR",
    description: "Used when the text has an amount and source but no target, such as 100 usd.",
    options: CurrencyCode.knownCodes.sorted().map {
      CatalogSettingDefinition.Option(value: $0, label: $0)
    }
  )

  static func defaultTargetText() -> String {
    let identifier = Bundle(for: CurrencyExtension.self).bundleIdentifier
      ?? "com.masalaempire.tuna.plugins.currency"
    let store = CatalogSettingStore(catalogIdentifier: identifier)
    let value = store.stringValue(for: defaultTarget)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return CurrencyCode(parsing: value)?.rawValue ?? defaultTarget.defaultValue
  }
}
