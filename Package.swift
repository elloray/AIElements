// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "AIElements",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AIElements", targets: ["AIElements"]),
        .executable(name: "AIElementsGallery", targets: ["AIElementsGallery"]),
        .executable(name: "aielements", targets: ["AIElementsCLI"])
    ],
    targets: [
        .target(name: "AIElements", resources: [.process("Resources")]),
        .executableTarget(name: "AIElementsGallery", dependencies: ["AIElements"]),
        .target(name: "AIElementsCLIKit", path: "Tools", resources: [.copy("Catalog"), .copy("Skills")]),
        .executableTarget(name: "AIElementsCLI", dependencies: ["AIElementsCLIKit"]),
        .testTarget(name: "AIElementsTests", dependencies: ["AIElements"]),
        .testTarget(name: "AIElementsCLIKitTests", dependencies: ["AIElementsCLIKit"])
    ]
)
