// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MinecraftDocker",
    platforms: [.macOS(.v12)],
    dependencies: [
        // CLI arguments parser
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        // Docker api
        .package(url: "https://gitlab.com/rdall96/docker-swift-api", from: "1.3.0"),
        // HTML parser
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "MinecraftDocker",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "DockerSwiftAPI", package: "docker-swift-api"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
            path: "Sources/"
        ),
        .testTarget(
            name: "MinecraftDockerTests",
            dependencies: [
                .target(name: "MinecraftDocker"),
            ],
            path: "Tests/"
        ),
    ]
)
