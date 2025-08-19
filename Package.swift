// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnvPocket",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "envpocket",
            targets: ["EnvPocket"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EnvPocket"
        ),
        .testTarget(
            name: "EnvPocketTests",
            dependencies: ["EnvPocket"]
        )
    ]
)