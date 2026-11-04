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
        minTuna: "0.80",
        minTunaKit: "1.14.0"
      ),
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
