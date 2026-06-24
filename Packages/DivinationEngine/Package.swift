// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DivinationEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "DivinationEngine", targets: ["DivinationEngine"])
    ],
    targets: [
        .target(
            name: "DivinationEngine"
        ),
        .testTarget(
            name: "DivinationEngineTests",
            dependencies: ["DivinationEngine"]
        )
    ]
)
