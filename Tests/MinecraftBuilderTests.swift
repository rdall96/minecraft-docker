//
//  MinecraftBuilderTests.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

@testable import MinecraftDocker
import XCTest
import DockerSwiftAPI

nonisolated(unsafe) fileprivate let dockerClient = DockerClient(connection: .defaultSocket)

protocol MinecraftBuilderTestCase: XCTestCase {
    var builder: MinecraftBuilder! { get }
    var builtImages: [Docker.Image] { get set }
    
    func build(minecraftVersion: GameVersion, imageName: String, tagLatest: Bool) async throws -> Docker.Image
    func cleanup() async throws
}

extension MinecraftBuilderTestCase {

    @discardableResult
    func build(minecraftVersion: GameVersion, imageName: String, tagLatest: Bool) async throws -> Docker.Image {
        let image = try await builder.build(
            minecraftVersion: minecraftVersion,
            imageName: imageName,
            tagLatest: tagLatest
        )
        builtImages.append(image)
        return image
    }
    
    func cleanup() async throws {
        for image in builtImages {
            try await dockerClient.remove(image, force: true)
        }
    }
}

// MARK: - Vanilla builder
final class VanillaBuilderTests: XCTestCase, MinecraftBuilderTestCase {
    var builder: MinecraftBuilder!
    var builtImages: [Docker.Image] = []
    
    override func tearDown() async throws {
        try await cleanup()
    }
    
    func testBuildHappyPath() async throws {
        builder = MinecraftBuilder(for: .vanilla, with: dockerClient)
        try await build(minecraftVersion: .init(minecraft: "1.20.1"), imageName: "minecraft", tagLatest: false)
    }
}

// MARK: - Fabric builder
final class FabricBuilderTests: XCTestCase, MinecraftBuilderTestCase {
    var builder: MinecraftBuilder!
    var builtImages: [Docker.Image] = []
    
    override func tearDown() async throws {
        try await cleanup()
    }
    
    func testBuildHappyPath() async throws {
        builder = MinecraftBuilder(for: .fabric, with: dockerClient)
        try await build(minecraftVersion: .init(minecraft: "1.20.1"), imageName: "minecraft", tagLatest: false)
    }
    
    func testBuildCustomVersion() async throws {
        builder = MinecraftBuilder(for: .fabric, with: dockerClient)
        try await build(
            minecraftVersion: .init(minecraft: "1.21", modLoader: "0.15.7"),
            imageName: "minecraft",
            tagLatest: false
        )
    }
}
