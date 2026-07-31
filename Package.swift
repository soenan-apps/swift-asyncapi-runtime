// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-asyncapi-runtime",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
  ],
  products: [
    .library(name: "AsyncAPIRuntime", targets: ["AsyncAPIRuntime"])
  ],
  targets: [
    .target(name: "AsyncAPIRuntime"),
    .testTarget(
      name: "AsyncAPIRuntimeTests",
      dependencies: ["AsyncAPIRuntime"]
    ),
  ]
)
