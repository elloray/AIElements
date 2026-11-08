// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "AIElements",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AIElements", targets: ["AIElements"]),
        .library(name: "AIElementsUIProtocol", targets: ["AIElementsUIProtocol"]),
        .executable(name: "AIElementsGallery", targets: ["AIElementsGallery"]),
        .executable(name: "aielements", targets: ["AIElementsCLI"])
    ],
    targets: [
        .target(name: "AIElementsUIProtocol", resources: [.copy("Resources")]),
        .target(name: "AIElements", dependencies: ["AIElementsUIProtocol"], resources: [.process("Resources")]),
        .executableTarget(name: "AIElementsGallery", dependencies: ["AIElements"]),
        .target(name: "AIElementsCLIKit", dependencies: ["AIElementsUIProtocol"], path: "Tools", resources: [.copy("Catalog"), .copy("Skills")]),
        .executableTarget(name: "AIElementsCLI", dependencies: ["AIElementsCLIKit"]),
        .testTarget(name: "AIElementsTests", dependencies: ["AIElements"]),
        .testTarget(name: "AIElementsCLIKitTests", dependencies: ["AIElementsCLIKit"]),
        .testTarget(name: "AIElementsUIProtocolTests", dependencies: ["AIElementsUIProtocol"])
    ]
)
