//
//  MinecraftBuilderTests.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

@testable import MinecraftDocker
import XCTest
import DockerSwiftAPI

protocol MinecraftBuilderTestCase: XCTestCase {
    var builder: MinecraftBuilder! { get }
    var builtImages: [Docker.Image] { get set }
    
    func build(minecraftVersion: MinecraftVersion, imageName: String, tagLatest: Bool) async throws -> [Docker.Image]
    func cleanup() async throws
}

extension MinecraftBuilderTestCase {
    
    func build(minecraftVersion: MinecraftVersion, imageName: String, tagLatest: Bool) async throws -> [Docker.Image] {
        let images = try await builder.build(
            minecraftVersion: minecraftVersion,
            imageName: imageName,
            tagLatest: tagLatest
        )
        builtImages.append(contentsOf: images)
        return images
    }
    
    func cleanup() async throws {
        for image in builtImages {
            try await Docker.remove(image: image)
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
        builder = MinecraftBuilder(minecraftType: .vanilla)
        let images = try await build(minecraftVersion: .init("1.20.1"), imageName: "minecraft", tagLatest: false)
        builtImages.append(contentsOf: images)
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
        builder = MinecraftBuilder(minecraftType: .fabric)
        let images = try await build(minecraftVersion: .init("1.20.1"), imageName: "minecraft", tagLatest: false)
        builtImages.append(contentsOf: images)
    }
}
