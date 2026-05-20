// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "pippin-mcp",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "pippin-mcp", targets: ["pippin-mcp"]),
        .library(name: "PippinCore", targets: ["PippinCore"]),
        .library(name: "PippinServer", targets: ["PippinServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "PippinCore",
            path: "Sources/PippinCore"
        ),
        .target(
            name: "PippinServer",
            dependencies: [
                "PippinCore",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/PippinServer"
        ),
        .executableTarget(
            name: "pippin-mcp",
            dependencies: [
                "PippinCore",
                "PippinServer",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Sources/pippin-mcp"
        ),
        .testTarget(
            name: "PippinCoreTests",
            dependencies: ["PippinCore"],
            path: "Tests/PippinCoreTests"
        ),
        .testTarget(
            name: "PippinServerTests",
            dependencies: ["PippinServer"],
            path: "Tests/PippinServerTests"
        ),
    ]
)
