// swift-tools-version: 5.9
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