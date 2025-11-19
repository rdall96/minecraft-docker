//
//  NeoForgedRuntime.swift
//  MinecraftDocker
//
//  Created by Ricky Dall'Armellina on 9/21/24.
//

import Foundation
import SwiftSoup

struct NeoForgedRuntime: MinecraftRuntime {
    let type: GameType = .neoForged
    let version: GameVersion
    let url: URL
    let name: String
    
    var executableName: String {
        "neoforge_installer.jar"
    }
    
    var installCommands: [String] {
        [
            "WORKDIR /tmp",
            "ADD \"\(url.absoluteString)\" ./\(executableName)",
            "RUN java -jar \(executableName) --install-server \(MinecraftRuntimeDefaults.homeDirectory)",
            "WORKDIR \(MinecraftRuntimeDefaults.homeDirectory)",
            "RUN rm -rf /tmp"
        ]
    }
    
    var startCommand: String {
        "bash run.sh --nogui $@"
    }
    
    var mappedVolumes: [String] {
        var volumes = MinecraftRuntimeDefaults.mappedVolumes
        volumes.append("mods")
        return volumes
    }
    
    let javaVersion: JavaVersion?
}

/// https://neoforged.net
final class NeoForgedRuntimeProvider: MinecraftRuntimeProvider {
    private static let versionListURL = URL(string: "https://maven.neoforged.net/releases/net/neoforged/neoforge/")!
    
    let session: URLSession
    private let vanillaProvider: VanillaRuntimeProvider
    
    init(session: URLSession) {
        self.session = session
        vanillaProvider = VanillaRuntimeProvider(session: session)
    }
    
    private func installer(for minecraftVersion: GameVersion) async throws -> NeoForgedVersion {
        let (data, response) = try await session.data(for: Self.versionListURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the neoforged versions")
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw MinecraftDockerError.serverDownload("Failed to decode server response")
        }
        guard httpResponse.statusCode == 200 else {
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the neoforged versions: \(content)")
        }
        guard let neoForged = NeoForgedVersion.latestVersion(from: content, for: minecraftVersion) else {
            throw MinecraftDockerError.serverDownload("No version of neoforged found for Miencraft: \(minecraftVersion)")
        }
        return neoForged
    }
    
    var availableVersions: [GameVersion] {
        get async throws {
            let vanillaVersions = try await vanillaProvider.availableVersions
            return await withTaskGroup(
                of: GameVersion?.self,
                returning: [GameVersion].self
            ) { group in
                for vanillaVersion in vanillaVersions {
                    group.addTask {
                        do {
                            _ = try await self.installer(for: vanillaVersion)
                            return vanillaVersion
                        }
                        catch {
                            MinecraftDockerLog.warning("No neoforge version found for Minecraft \(vanillaVersion), ignoring...")
                            return nil
                        }
                    }
                }
                var versions = [GameVersion]()
                for await result in group.compactMap({ $0 }) {
                    versions.append(result)
                }
                return versions
            }
        }
    }
    
    func runtime(for version: GameVersion) async throws -> any MinecraftRuntime {
        let installer = try await installer(for: version)
        return NeoForgedRuntime(
            version: version,
            url: installer.installerUrl(base: Self.versionListURL),
            name: "\(version.minecraft)-\(GameType.neoForged.rawValue)_\(installer.version)",
            javaVersion: .init(rawValue: try await vanillaProvider.info(for: version).javaVersion)
        )
    }
    
    
}

// MARK: - Data model

struct NeoForgedVersion {
    
    let version: String
    
    func url(base: URL) -> URL {
        base.appendingPathComponent(version)
    }
    
    func installerUrl(base: URL) -> URL {
        url(base: base).appendingPathComponent("neoforge-\(version)-installer.jar")
    }
    
    /// Find the best NeoForged version from the given HTML page
    static func latestVersion(from html: String, for minecraftVersion: GameVersion) -> NeoForgedVersion? {
        // NeoForged versions major version is the Minecraft minor version
        // i.e.: NeoForged 20.2.3  -> Minecraft 1.20.2
        //       NeoForged 21.2.57 -> Minecraft 1.21.1
        let minecraftVersionString = minecraftVersion.minecraftVersionComponents
            .dropFirst()
            .compactMap { String($0) }
            .joined(separator: ".")
        return versions(from: html).last {
            $0.version.hasPrefix(minecraftVersionString)
        }
    }
    
    static func versions(from html: String) -> [NeoForgedVersion] {
        guard let document = try? SwiftSoup.parse(html) else { return [] }
        /**
         <body>
            <h1>Index of /releases/net/neoforged/neoforge/</h1>
            <ul>
                <li class='back'>
                    <a href='/releases/net/neoforged'>Parent Directory</a>
                </li>
                <li class="directory">
                    <a href="./20.2.3-beta/">20.2.3-beta/</a>
                </li>
                [...]
            </ul>
         </body>
         */
        let versionList = try? document.body()?
            .select("ul")
            .select("li.directory")
            .select("a")
        
        let versions = versionList?.array() ?? []
        
        return versions.compactMap {
            guard let versionName = try? $0.text() else {
                return nil
            }
            
            return NeoForgedVersion(
                version: versionName.replacingOccurrences(of: "/", with: "")
            )
        }
    }
}
