// swift-tools-version: 6.1
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
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.4"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),

        .package(url: "https://github.com/reers/ReerCodable.git", branch: "main"),
        //        .package(url: "https://github.com/reers/ReerCodable.git", from: "1.2.3"),
    ],
    targets: [
        .executableTarget(
            name: "vps-db-tool",
            dependencies: [
                "VPSDB",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "VPSDB",
            dependencies: [
                "SwiftSoup",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ReerCodable", package: "ReerCodable"),
            ]
        ),
        .testTarget(
            name: "VPSDBTests",
            dependencies: [
                "VPSDB",
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
    ]
)
