// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ArenaKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ArenaKit", targets: ["ArenaKit"])
    ],
    targets: [
        .target(name: "ArenaKit"),
        .testTarget(
            name: "ArenaKitTests",
            dependencies: ["ArenaKit"]
        ),
    ]
)
