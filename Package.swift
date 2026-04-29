// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xcatalog",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xcatalog", targets: ["xcatalog"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", exact: "0.12.0"),
    ],
    targets: [
        // コアライブラリ（モデル・パーサー）
        .target(name: "XCStringsKit"),

        // CLIコマンド実装
        .target(
            name: "XCStringsCLI",
            dependencies: [
                "XCStringsKit",
                "XCStringsMCP",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MCPサーバー実装
        .target(
            name: "XCStringsMCP",
            dependencies: [
                "XCStringsKit",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),

        // CLI実行ファイル
        .executableTarget(
            name: "xcatalog",
            dependencies: ["XCStringsCLI"]
        ),

        // テスト
        .testTarget(
            name: "XCStringsKitTests",
            dependencies: ["XCStringsKit"]
        ),
        .testTarget(
            name: "XCStringsCLITests",
            dependencies: [
                "XCStringsCLI",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "XCStringsMCPTests",
            dependencies: [
                "XCStringsMCP",
                "XCStringsKit",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
