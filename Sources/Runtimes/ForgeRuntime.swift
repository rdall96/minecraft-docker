//
//  ForgeRuntime.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/11/23.
//

import Foundation
import SwiftSoup

struct ForgeRuntime: MinecraftRuntime {
    let type: GameType = .forge
    let version: GameVersion
    let url: URL
    let name: String
    
    var executableName: String {
        "forge_installer.jar"
    }
    
    var installCommands: [String] {
        [
            "WORKDIR /tmp",
            "ADD \"\(url.absoluteString)\" ./\(executableName)",
            "RUN java -jar \(executableName) --installServer \(MinecraftRuntimeDefaults.homeDirectory)",
            "WORKDIR \(MinecraftRuntimeDefaults.homeDirectory)",
            "RUN rm -rf /tmp"
        ]
    }
    
    var startCommand: String {
        """
        if [[ -e "run.sh" ]]; then
            bash run.sh --nogui
        else
            java $(cat user_jvm_args.txt) -jar forge*.jar --nogui
        fi
        """
    }
    
    var mappedVolumes: [String] {
        var volumes = MinecraftRuntimeDefaults.mappedVolumes
        volumes.append("mods")
        return volumes
    }
    
    let javaVersion: JavaVersion?
}

/// https://files.minecraftforge.net/net/minecraftforge/forge/index_1.16.5.html
final class ForgeRuntimeProvider: MinecraftRuntimeProvider {
    static private func versionsHtmlUrl(minecraft: String) -> URL {
        URL(string: "https://files.minecraftforge.net/net/minecraftforge/forge/index_\(minecraft).html")!
    }
    
    let session: URLSession
    private let vanillaProvider: VanillaRuntimeProvider
    
    init(session: URLSession) {
        self.session = session
        vanillaProvider = VanillaRuntimeProvider(session: session)
    }
    
    private func installers(for minecraftVersion: String) async throws -> [ForgeVersion] {
        let (data, response) = try await session.data(for: Self.versionsHtmlUrl(minecraft: minecraftVersion))
        // Ensure we get a valid response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the forge versions")
        }
        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the forge versions: \(error)")
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw MinecraftDockerError.serverDownload("Received invalid forge versions data")
        }
        return ForgeVersion.versions(from: content)
    }
    
    private func latestInstaller(for minecraftVersion: String) async throws -> ForgeVersion {
        let latestForge = try await installers(for: minecraftVersion).first { $0.isLatest }
        guard let latestForge else {
            throw MinecraftDockerError.serverDownload("No version of forge found for Minecraft \(minecraftVersion)")
        }
        return latestForge
    }
    
    var availableVersions: [GameVersion] {
        get async throws {
            let vanillaVersions = try await vanillaProvider.availableVersions
            // the forge versions will be limited the loaders provided, so we need to fetch the loaders for each version
            // (thankfully thread pools are a thing)
            return await withTaskGroup(
                of: [GameVersion].self,
                returning: [GameVersion].self
            ) { group in
                for version in vanillaVersions {
                    group.addTask {
                        do {
                            return try await self.installers(for: version.minecraft)
                                .compactMap { GameVersion(minecraft: version.minecraft, modLoader: $0.version) }
                        }
                        catch {
                            // Keep this commented out as it can be spammy, it's useful for debugging though
//                            MinecraftDockerLog.warning("No forge version found for Minecraft \(vanillaVersion), ignoring...")
                            return []
                        }
                    }
                }
                var versions = [GameVersion]()
                for await result in group {
                    versions.append(contentsOf: result)
                }
                return versions
            }
        }
    }
    
    func runtime(for version: GameVersion) async throws -> MinecraftRuntime {
        let forge: ForgeVersion
        if let modLoaderVersion = version.modLoader {
            // allow unstable versions when the mod loader version is specified
            let requestedLoader = try await installers(for: version.minecraft).first {
                $0.version == modLoaderVersion
            }
            guard let requestedLoader else {
                MinecraftDockerLog.error("The requested forge version \(modLoaderVersion) is not available for Minecraft \(version.minecraft)")
                throw MinecraftDockerError.invalidGameVersion
            }
            forge = requestedLoader
        }
        else {
            forge = try await latestInstaller(for: version.minecraft)
        }
        return ForgeRuntime(
            version: version,
            url: forge.url,
            name: "\(version.minecraft)-\(GameType.forge.rawValue)_\(forge.version)",
            javaVersion: .init(rawValue: try await vanillaProvider.info(for: version).javaVersion)
        )
    }
}

// MARK: - Data model

struct ForgeVersion {
    
    let version: String
    let isLatest: Bool
    let url: URL
    
    static func versions(from html: String) -> [ForgeVersion] {
        var versions: [ForgeVersion] = []
        
        guard let document = try? SwiftSoup.parse(html) else { return [] }
        /**
         <main class="wrapper">
         <div class="sidebar-sticky-wrapper-content">
         <div class="download-container">
         <div class="download-list-wrapper">
         <table class="download-list">
         <tbody>
         <tr> DOWNLOAD INFO</tr>
         </tbody>
         </table>
         </div>
         </div>
         </div>
         </main>
         */
        let downloads = try? document.body()?
            .select("table.download-list")
            .select("tbody")
            .select("tr")
            .array()
        for download in downloads ?? [] {
            /**
             <tr>
             <td class="download-version">
             47.1.44
             <i class="(promo-recommended|promo-latest)"></i>
             </td>
             <td class="download-time" title="2023-07-07 03:45:35">2023-07-07</td>
             <td class="download-files">
             <ul class="download-links">DOWNLOAD FILES</ul>
             </td>
             </tr>
             */
            guard let versionContainer = try? download.select("td.download-version").first(),
                  let version = try? versionContainer.text()
            else { continue }
            
            let isLatest = (try? versionContainer.select("i.promo-latest")) != nil
//            let isRecommended = (try? versionContainer.select("i.promo-recommended")) != nil
            
            /// <li>DATA</li>
            // It's a waste of time to parse through all the data at this point, jsut get all the <a> tags
            // and inspect the link (href) of each one. We want the ones that end in `-installer.jar`
            guard let downloadLinksContainer = try? download.select("ul.download-links"),
                  let aContainers = try? downloadLinksContainer.select("a").array()
            else { continue }
            
            // Forge uses `adfoc.us` to show ads on links, so skip those since we want a direct download
            let link: String? = aContainers.lazy
                .compactMap { try? $0.attr("href") }
                .filter { !$0.contains("adfoc.us") }
                .filter { $0.contains("-installer.jar") }
                .first
            guard let link, let url = URL(string: link) else { continue }
            
            versions.append(
                ForgeVersion(version: version, isLatest: isLatest, url: url)
            )
        }
        
        return versions
    }
    
    /// Find the best Forge version from the given HTML page
    static func latestVersion(from html: String) -> ForgeVersion? {
        versions(from: html).first
    }
}
