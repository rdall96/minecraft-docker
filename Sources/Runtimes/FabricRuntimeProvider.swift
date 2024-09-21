//
//  FabricRuntimeProvider.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

struct FabricRuntime: MinecraftRuntime {
    let type: MinecraftType = .fabric
    let version: MinecraftVersion
    let url: URL
    let name: String
    
    var executableName: String {
        "fabric_server.jar"
    }
    
    var installCommands: [String] {
        ["ADD \"\(url.absoluteString)\" \(MinecraftRuntimeDefaults.homeDirectory)/\(executableName)"]
    }
    
    var startCommand: String { "java -jar \(executableName) nogui" }
    
    var mappedVolumes: [String] {
        var volumes = MinecraftRuntimeDefaults.mappedVolumes
        volumes.append("mods")
        return volumes
    }
    
    let javaVersion: JavaVersion?
}

/// https://fabricmc.net
final class FabricRuntimeProvider: MinecraftRuntimeProvider {
    static private func loaderJsonUrl(minecraft: String) -> URL {
        URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(minecraft)")!
    }
    static private let installerJsonUrl = URL(string: "https://meta.fabricmc.net/v2/versions/installer")!
    static private func jarDownloadUrl(minecraft: String, loader: String, installer: String) -> URL {
        URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(minecraft)/\(loader)/\(installer)/server/jar")!
    }
    
    let session: URLSession
    private let vanillaProvider: VanillaRuntimeProvider
    
    init(session: URLSession) {
        self.session = session
        vanillaProvider = VanillaRuntimeProvider(session: session)
    }
    
    private func latestFabricLoader(for minecraftVersion: MinecraftVersion, allowUnstable: Bool = false) async throws -> FabricLoader {
        let (data, response) = try await session.data(for: Self.loaderJsonUrl(minecraft: minecraftVersion.rawValue))
        // Ensure we get a valid response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the fabric loader versions")
        }
        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the fabric loader versions: \(error)")
        }
        // parse the response data and cache the versions manifest
        do {
            let loaders = try JSONDecoder().decode([FabricLoader].self, from: data)
            let loader = loaders.first {
                if allowUnstable { return true }
                return $0.loader.stable && $0.intermediary.stable
            }
            guard let loader else {
                throw MinecraftDockerError.serverDownload("No valid Fabric loaders found")
            }
            return loader
        }
        catch {
            throw MinecraftDockerError.serverDownload("Invalid fabric loaders data: \(error)")
        }
    }
    
    private func latestInstaller(allowUnstable: Bool = false) async throws -> FabricInstaller {
        let (data, response) = try await session.data(for: Self.installerJsonUrl)
        // Ensure we get a valid response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the fabric installer versions")
        }
        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the fabric installer versions: \(error)")
        }
        // parse the response data and cache the versions manifest
        do {
            let installers = try JSONDecoder().decode([FabricInstaller].self, from: data)
            let installer = installers.first { allowUnstable || $0.stable }
            guard let installer else {
                throw MinecraftDockerError.serverDownload("No valid Fabric installers found")
            }
            return installer
        }
        catch {
            throw MinecraftDockerError.serverDownload("Invalid fabric installers data: \(error)")
        }
    }
    
    var availableVersions: [MinecraftVersion] {
        get async throws {
            let vanillaVersions = try await vanillaProvider.availableVersions
            // the fabric versions will be limited the loaders provided, so we need to fetch the loaders for each version
            // (thankfully thread pools are a thing)
            return await withTaskGroup(
                of: MinecraftVersion?.self,
                returning: [MinecraftVersion].self
            ) { group in
                for vanillaVersion in vanillaVersions {
                    group.addTask {
                        do {
                            _ = try await self.latestFabricLoader(for: vanillaVersion)
                            return vanillaVersion
                        }
                        catch {
                            // Keep this commented out as it can be spammy, it's useful for debugging though
//                            MinecraftDockerLog.warning("No fabric version found for Minecraft \(vanillaVersion), ignoring...")
                            return nil
                        }
                    }
                }
                var versions = [MinecraftVersion]()
                for await result in group.compactMap({ $0 }) {
                    versions.append(result)
                }
                return versions
            }
        }
    }
    
    func runtime(for version: MinecraftVersion) async throws -> MinecraftRuntime {
        // ensure the minecraft version is valid
        guard try await availableVersions.contains(version) else {
            throw MinecraftDockerError.invalidMinecraftVersion
        }
        // get the loader
        let loader = try await latestFabricLoader(for: version)
        // get the installer
        let installer = try await latestInstaller()
        // assemble url
        let url = Self.jarDownloadUrl(
            minecraft: version.rawValue,
            loader: loader.loader.version,
            installer: installer.version
        )
        
        return FabricRuntime(
            version: version,
            url: url,
            name: "\(version.rawValue)-\(MinecraftType.fabric.rawValue)_\(loader.loader.version)",
            javaVersion: .init(rawValue: try await vanillaProvider.info(for: version).javaVersion)
        )
    }
}

// MARK: - Data model

fileprivate struct FabricInstaller: Decodable {
    /**
     {
         "url": "https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.11.2/fabric-installer-0.11.2.jar",
         "maven": "net.fabricmc:fabric-installer:0.11.2",
         "version": "0.11.2",
         "stable": true
     }
     */
    let url: URL
    let version: String
    let stable: Bool
}

fileprivate struct FabricLoader: Decodable {
    /**
     {
         "loader": <Info>,
         "intermediary": <Intermediary>,
         "launcherMeta": <LauncherMeta> (ignored)
     }
     */
    
    struct Info: Decodable {
        /**
         {
             "separator": ".",
             "build": 22,
             "maven": "net.fabricmc:fabric-loader:0.14.22",
             "version": "0.14.22",
             "stable": true
         }
         */
        let build: UInt
        let version: String
        let stable: Bool
    }
    
    struct Intermediary: Decodable {
        /**
         {
             "maven": "net.fabricmc:intermediary:1.20.1",
             "version": "1.20.1",
             "stable": true
         }
         */
        let version: String
        let stable: Bool
    }
    
    struct LauncherMeta: Decodable {
        /**
         {
             "version": 1,
             "libraries": {
                 "client": [],
                 "common": [
                     {
                     "name": "net.fabricmc:tiny-mappings-parser:0.3.0+build.17",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "net.fabricmc:sponge-mixin:0.12.5+mixin.0.8.5",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "net.fabricmc:tiny-remapper:0.8.2",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "net.fabricmc:access-widener:2.1.0",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "org.ow2.asm:asm:9.5",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "org.ow2.asm:asm-analysis:9.5",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "org.ow2.asm:asm-commons:9.5",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "org.ow2.asm:asm-tree:9.5",
                     "url": "https://maven.fabricmc.net/"
                     },
                     {
                     "name": "org.ow2.asm:asm-util:9.5",
                     "url": "https://maven.fabricmc.net/"
                     }
                 ],
                 "server": []
             },
             "mainClass": {
                 "client": "net.fabricmc.loader.impl.launch.knot.KnotClient",
                 "server": "net.fabricmc.loader.impl.launch.knot.KnotServer"
             }
         }
         */
        let version: UInt
    }
    
    let loader: Info
    let intermediary: Intermediary
    let launcherMeta: LauncherMeta
}
