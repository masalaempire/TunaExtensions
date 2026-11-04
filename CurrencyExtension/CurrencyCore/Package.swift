// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CurrencyCore",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "CurrencyCore", targets: ["CurrencyCore"])
  ],
  targets: [
    .target(name: "CurrencyCore"),
    .testTarget(name: "CurrencyCoreTests", dependencies: ["CurrencyCore"])
  ]
)
