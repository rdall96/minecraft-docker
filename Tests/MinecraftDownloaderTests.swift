//
//  MinecraftDownloaderTests.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

@testable import MinecraftDocker
import XCTest

protocol MinecraftDownloaderTestCase: XCTestCase {
    var downloader: MinecraftDownloader { get }
    func testAvailableVersions() async throws
    func testDownloadVersionHappyPath() async throws
    func testDownloadInvalidVersion() async throws
}

// MARK: - Vanilla downloader
final class VanillaDownloaderTests: XCTestCase, MinecraftDownloaderTestCase {
    let downloader: MinecraftDownloader = MinecraftDownloader(for: .vanilla)
    
    func testAvailableVersions() async throws {
        let versions = try await downloader.runtimeProvider.availableVersions
        XCTAssertGreaterThan(versions.count, 0)
    }
    
    func testDownloadVersionHappyPath() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        let jarPath = try await downloader.download(version: .init(minecraft: "1.20.1"), to: tempPath)
        XCTAssert(
            FileManager.default.fileExists(atPath: jarPath.path)
        )
    }
    
    func testDownloadInvalidVersion() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        do {
            try await downloader.download(version: .init(minecraft: "def_not_a_minecraft_version"), to: tempPath)
            XCTFail("This is supposed to fail")
        }
        catch is MinecraftDockerError {
            // no-op
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Fabric downloader
final class FabricDownloaderTests: XCTestCase, MinecraftDownloaderTestCase {
    let downloader: MinecraftDownloader = MinecraftDownloader(for: .fabric)
    
    func testAvailableVersions() async throws {
        let versions = try await downloader.runtimeProvider.availableVersions
        XCTAssertGreaterThan(versions.count, 0)
    }
    
    func testDownloadVersionHappyPath() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        let jarPath = try await downloader.download(version: .init(minecraft: "1.20.1"), to: tempPath)
        XCTAssert(
            FileManager.default.fileExists(atPath: jarPath.path)
        )
    }
    
    func testDownloadCustomVersion() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        let jarPath = try await downloader.download(
            version: .init(minecraft: "1.20.1", modLoader: "0.14.1"),
            to: tempPath
        )
        XCTAssert(
            FileManager.default.fileExists(atPath: jarPath.path)
        )
    }
    
    func testDownloadInvalidVersion() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        do {
            try await downloader.download(version: .init(minecraft: "def_not_a_minecraft_version"), to: tempPath)
            XCTFail("This is supposed to fail")
        }
        catch is MinecraftDockerError {
            // no-op
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Forge downloader
final class ForgeDownloaderTests: XCTestCase, MinecraftDownloaderTestCase {
    let downloader: MinecraftDownloader = MinecraftDownloader(for: .forge)
    
    func testAvailableVersions() async throws {
        let versions = try await downloader.runtimeProvider.availableVersions
        XCTAssertGreaterThan(versions.count, 0)
    }
    
    func testDownloadVersionHappyPath() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        let jarPath = try await downloader.download(version: .init(minecraft: "1.20.1"), to: tempPath)
        XCTAssert(
            FileManager.default.fileExists(atPath: jarPath.path)
        )
    }
    
    func testDownloadInvalidVersion() async throws {
        let tempPath = FileManager.default.temporaryDirectory
        do {
            try await downloader.download(version: .init(minecraft: "def_not_a_minecraft_version"), to: tempPath)
            XCTFail("This is supposed to fail")
        }
        catch is MinecraftDockerError {
            // no-op
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
