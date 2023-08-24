//
//  MinecraftRuntime.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol MinecraftRuntime {
    /// Type of Minecraft runtime
    var type: MinecraftType { get }
    /// Minecraft version
    var version: MinecraftVersion { get }
    /// URL to download this runtime
    var url: URL { get }
    /// A name representation of this version
    var name: String { get }
    
    /// Name of this runtime executable
    var executableName: String { get }
    /// Commands to install this runtime
    var installCommands: [String] { get }
    /// Command to start this runtime
    var startCommand: String { get }
    
    /// Docker volumes to map for this runtime
    var mappedVolumes: [String] { get }
    
    /// Optimal java for this Minecraft runtime
    var javaVersion: JavaVersion? { get }
}

protocol MinecraftRuntimeProvider {
    var session: URLSession { get }
    
    /// List all the available game version for this type of Miencraft
    var availableVersions: [MinecraftVersion] { get async throws }
    
    /// Get the latest version available
    var latestVersion: MinecraftVersion { get async throws }
    
    /// Get the download URL for this server version
    func runtime(for version: MinecraftVersion) async throws -> MinecraftRuntime
}

extension MinecraftRuntimeProvider {
    var latestVersion: MinecraftVersion {
        get async throws {
            let versions = try await availableVersions.sorted(by: >)
            guard let latest = versions.first else {
                throw MinecraftDockerError.serverDownload("No Minecraft versions found")
            }
            return latest
        }
    }
}
