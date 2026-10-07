// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenAway",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenAway", targets: ["OpenAway"])],
    targets: [
        .target(name: "OpenAwayCore"),
        .executableTarget(name: "OpenAway", dependencies: ["OpenAwayCore"]),
        .testTarget(name: "OpenAwayCoreTests", dependencies: ["OpenAwayCore"]),
    ]
)
