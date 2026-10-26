// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StreamHubCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "StreamHubCore", targets: ["StreamHubCore"])],
    targets: [
        .target(name: "StreamHubCore"),
        .testTarget(name: "StreamHubCoreTests", dependencies: ["StreamHubCore"])
    ]
)
