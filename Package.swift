// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vps-db-tools",

    platforms: [
        .macOS(.v15)
    ],

    products: [
        .executable(name: "vps-db-tool", targets: ["vps-db-tool"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.1.2")
        ),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0-beta.1"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),

        .package(url: "https://github.com/SwiftyLab/MetaCodable.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "vps-db-tool",
            dependencies: [
                "SwiftSoup",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "MetaCodable", package: "MetaCodable"),
                .product(name: "HelperCoders", package: "MetaCodable"),
            ]
        )
    ]
)
