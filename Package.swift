// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Flowline",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "FlowlineCore", targets: ["FlowlineCore"]),
    .executable(name: "Flowline", targets: ["FlowlineApp"])
  ],
  targets: [
    .target(
      name: "FlowlineCore"
    ),
    .executableTarget(
      name: "FlowlineApp",
      dependencies: ["FlowlineCore"]
    ),
    .testTarget(
      name: "FlowlineCoreTests",
      dependencies: ["FlowlineCore"]
    )
  ]
)
