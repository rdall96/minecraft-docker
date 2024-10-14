//
//  ForgeRuntimeProvider.swift
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
            java -jar forge*.jar --nogui
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
    
    func installer(for minecraftVersion: GameVersion) async throws -> ForgeVersion {
        let (data, response) = try await session.data(for: Self.versionsHtmlUrl(minecraft: minecraftVersion.minecraft))
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
        guard let forge = ForgeVersion.latestVersion(from: content) else {
            throw MinecraftDockerError.serverDownload("No version of forge found for Minecraft \(minecraftVersion)")
        }
        return forge
    }
    
    var availableVersions: [GameVersion] {
        get async throws {
            let vanillaVersions = try await vanillaProvider.availableVersions
            // the forge versions will be limited the loaders provided, so we need to fetch the loaders for each version
            // (thankfully thread pools are a thing)
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
                            // Keep this commented out as it can be spammy, it's useful for debugging though
//                            MinecraftDockerLog.warning("No forge version found for Minecraft \(vanillaVersion), ignoring...")
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
    
    func runtime(for version: GameVersion) async throws -> MinecraftRuntime {
        let installer = try await installer(for: version)
        return ForgeRuntime(
            version: version,
            url: installer.url,
            name: "\(version.minecraft)-\(GameType.forge.rawValue)_\(installer.version)",
            javaVersion: .init(rawValue: try await vanillaProvider.info(for: version).javaVersion)
        )
    }
}

// MARK: - Data model

struct ForgeVersion {
    
    let version: String
    let url: URL
    
    /// Find the best Forge version from the given HTML page
    static func latestVersion(from html: String) -> ForgeVersion? {
        // there's not point in storing all the versions, just keep track of the latest
        var latestVersion: ForgeVersion? = nil
        
        guard let document = try? SwiftSoup.parse(html) else { return nil }
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
        for download in downloads?.array() ?? [] {
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
            
            // FIXME: This is discarding older versions of Forge that have both tags
            // older versions of the game now have stable versions of forge, so if we can't find the latest, we should look for `promo-recommended`
            let isLatest = (try? versionContainer.select("i.promo-latest")) != nil || (try? versionContainer.select("i.promo-recommended")) != nil
            // we don't care about versions that are neither latest nor recommended
            guard isLatest else { continue }
            
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
            
            latestVersion = .init(version: version, url: url)
        }
        
        return latestVersion
    }
}
