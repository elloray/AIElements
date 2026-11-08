// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "AIElements",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AIElements", targets: ["AIElements"]),
        .executable(name: "AIElementsGallery", targets: ["AIElementsGallery"])
    ],
    targets: [
        .target(name: "AIElements", resources: [.process("Resources")]),
        .executableTarget(name: "AIElementsGallery", dependencies: ["AIElements"]),
        .testTarget(name: "AIElementsTests", dependencies: ["AIElements"])
    ]
)
