//
//  VanillaRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

struct VanillaRuntime: MinecraftRuntime {
    let type: GameType = .vanilla
    let version: GameVersion
    let url: URL
    let name: String
    
    var executableName: String { "server.jar" }
    
    var installCommands: [String] {
        ["ADD \"\(url.absoluteString)\" \(MinecraftRuntimeDefaults.homeDirectory)/\(executableName)"]
    }
    
    var startCommand: String { "java $(cat user_jvm_args.txt) -jar \(executableName) $@" }
    
    var mappedVolumes: [String] {
        MinecraftRuntimeDefaults.mappedVolumes
    }
    
    let javaVersion: JavaVersion?
}

/// https://www.minecraft.net/en-us
/// API: https://wiki.vg/Mojang_API
/// Alt: https://mcversions.net
final class VanillaRuntimeProvider: MinecraftRuntimeProvider {
    static private let versionJsonUrl = URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")!
    
    let session: URLSession
    private var versionsManifest: VanillaVersionManifest? = nil
    
    init(session: URLSession) {
        self.session = session
    }
    
    private func cacheAvailableVersions() async throws {
        // make the request
        let (versionData, response) = try await session.data(for: Self.versionJsonUrl)
        
        // Ensure we get a valid response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the version manifest")
        }
        guard httpResponse.statusCode == 200 else {
            let error = String(data: versionData, encoding: .utf8) ?? "Unknown error"
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the version manifest: \(error)")
        }
        
        // parse the response data and cache the versions manifest
        do {
            versionsManifest = try JSONDecoder().decode(VanillaVersionManifest.self, from: versionData)
        }
        catch {
            throw MinecraftDockerError.serverDownload("Invalid version manifest data: \(error)")
        }
    }
    
    var availableVersions: [GameVersion] {
        get async throws {
            // make sure we have version data
            if versionsManifest == nil {
                try await cacheAvailableVersions()
            }
            // we only want to return `release` versions, and keep the order
            return versionsManifest?.versions.lazy
                .filter { $0.type == .release }
                .compactMap { .init(minecraft: $0.id) } ?? []
        }
    }
    
    func info(for version: GameVersion) async throws -> VanillaVersionInfo {
        // make sure we have version data
        if versionsManifest == nil {
            try await cacheAvailableVersions()
        }
        // make sure we have a download url for this version info
        let versionInfoUrl = versionsManifest?.versions
            .first(where: { $0.id == version.minecraft })?.url
        guard let versionInfoUrl else {
            throw MinecraftDockerError.invalidGameVersion
        }
        
        // download the version info
        let (versionInfoData, response) = try await session.data(for: versionInfoUrl)
        // Ensure we get a valid response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the download information for version: \(version)")
        }
        guard httpResponse.statusCode == 200 else {
            let error = String(data: versionInfoData, encoding: .utf8) ?? "Unknown error"
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the version (\(version)) information: \(error)")
        }
        
        // parse the response data and cache the versions manifest
        do {
            return try JSONDecoder().decode(VanillaVersionInfo.self, from: versionInfoData)
        }
        catch {
            throw MinecraftDockerError.serverDownload("Invalid version information data: \(error)")
        }
    }
    
    func runtime(for version: GameVersion) async throws -> MinecraftRuntime {
        let versionInfo = try await info(for: version)
        
        guard let serverDownloadUrl = versionInfo.downloads[.server]?.url else {
            throw MinecraftDockerError.serverDownload("No server download URL found for version: \(version)")
        }
        return VanillaRuntime(
            version: version,
            url: serverDownloadUrl,
            name: version.minecraft,
            javaVersion: .init(rawValue: versionInfo.javaVersion)
        )
    }
}

// MARK: - Data model

fileprivate struct VanillaVersionManifest: Decodable {
    /**
     {
         "latest": {
             "release": "1.20.1",
             "snapshot": "23w32a"
         },
         "versions": [
             {
                 "id": "23w32a",
                 "type": "snapshot",
                 "url": "https://piston-meta.mojang.com/v1/packages/9b9d01ff2db2fd414f19578b1830b61fb9fb4804/23w32a.json",
                 "time": "2023-08-09T12:21:05+00:00",
                 "releaseTime": "2023-08-09T12:14:25+00:00"
            },
            ...
        ]
     }
     */
    
    struct Latest: Decodable {
        let release: String
        let snapshot: String
    }
    
    struct Version: Decodable {
        
        enum ReleaseType: String, Decodable {
            case release
            case snapshot
            case oldBeta = "old_beta"
            case oldAlpha = "old_alpha"
        }
        
        let id: String
        let type: ReleaseType
        let url: URL
    }
    
    let latest: Latest
    let versions: [Version]
}

struct VanillaVersionInfo: Decodable {
    /**
     {
         "client": {
             "sha1": "ca51bf36913a7333c055096a52a3a96fbdb11813",
             "size": 23069961,
             "url": "https://piston-data.mojang.com/v1/objects/ca51bf36913a7333c055096a52a3a96fbdb11813/client.jar"
         },
         "client_mappings": {
             "sha1": "1c17aca622d87e393aae115137dcfd570b9c5d7b",
             "size": 8137217,
             "url": "https://piston-data.mojang.com/v1/objects/1c17aca622d87e393aae115137dcfd570b9c5d7b/client.txt"
         },
         "server": {
             "sha1": "11ef2ae139b0badda80a1ea07c2dd0cf9034a32f",
             "size": 47907973,
             "url": "https://piston-data.mojang.com/v1/objects/11ef2ae139b0badda80a1ea07c2dd0cf9034a32f/server.jar"
         },
         "server_mappings": {
             "sha1": "9c53d6835200aa4e6d771f774ee499e37864f4e6",
             "size": 6246383,
             "url": "https://piston-data.mojang.com/v1/objects/9c53d6835200aa4e6d771f774ee499e37864f4e6/server.txt"
         }
     }
     */
    
    enum DownloadType: String, Decodable {
        case client
        case clientMappings = "client_mappings"
        case server
        case serverMappings = "server_mappings"
    }
    
    struct Download: Decodable {
        /**
         {
             "sha1": "ca51bf36913a7333c055096a52a3a96fbdb11813",
             "size": 23069961,
             "url": "https://piston-data.mojang.com/v1/objects/ca51bf36913a7333c055096a52a3a96fbdb11813/client.jar"
         }
         */
        let sha1: String
        let size: UInt64
        let url: URL
    }
    
    struct JavaVersionData: Decodable {
        let component: String
        let majorVersion: UInt
    }
    
    private enum Keys: String, CodingKey {
        case id
        case javaVersion
        case downloads
    }
    
    let id: String // should match the request version
    let javaVersion: UInt // optimal java version for this server
    let downloads: [DownloadType:Download] // list of downloads for this version: client, server, and extras...
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        self.id = try container.decode(String.self, forKey: .id)
        if let javaVersion = try? container.decode(JavaVersionData.self, forKey: .javaVersion) {
            self.javaVersion = javaVersion.majorVersion
        }
        else {
            self.javaVersion = 8 // default java that Minecraft used for a long time, some older versions (i.e.: 1.6) don't have this property specified
        }
        var downloads = [DownloadType:Download]()
        for (key, value) in try container.decode([String:Download].self, forKey: .downloads) {
            guard let downloadType = DownloadType(rawValue: key) else { continue }
            downloads[downloadType] = value
        }
        self.downloads = downloads
    }
}
