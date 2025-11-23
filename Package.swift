// swift-tools-version: 6.2.1

import PackageDescription

let package = Package(
    name: "MinecraftDocker",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        // CLI arguments parser
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.6.2")),
        // Docker api
        // FIXME: Switch to the proper release tag when it's available!
        .package(url: "https://gitlab.com/rdall96/docker-swift-api", branch: "dev/socket_communication"),
        // HTML parser
        .package(url: "https://github.com/scinfu/SwiftSoup.git", .upToNextMinor(from: "2.9.6")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "MinecraftDocker",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
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
