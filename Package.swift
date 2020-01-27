// swift-tools-version:5.1
import PackageDescription

let package = Package(
  name: "Parsey",
  products: [
    .library(name: "Parsey", targets: ["Parsey"])
  ],
  dependencies: [
  ],
  targets: [
    .target(name: "Parsey", dependencies: []),
    .testTarget(name: "ParseyTests", dependencies: ["Parsey"])
  ]
)
