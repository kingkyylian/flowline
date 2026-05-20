// swift-tools-version: 6.0

import PackageDescription

let isolatedDeinitSettings: [SwiftSetting] = [
  .enableExperimentalFeature("IsolatedDeinit")
]

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
      name: "FlowlineCore",
      swiftSettings: isolatedDeinitSettings
    ),
    .executableTarget(
      name: "FlowlineApp",
      dependencies: ["FlowlineCore"],
      swiftSettings: isolatedDeinitSettings
    ),
    .testTarget(
      name: "FlowlineCoreTests",
      dependencies: ["FlowlineCore"],
      swiftSettings: isolatedDeinitSettings
    ),
    .testTarget(
      name: "FlowlineAppTests",
      dependencies: ["FlowlineApp", "FlowlineCore"],
      swiftSettings: isolatedDeinitSettings
    )
  ]
)
