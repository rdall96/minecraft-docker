//
//  QuiltRuntime.swift
//  MinecraftDocker
//
//  Created by Ricky Dall'Armellina on 9/21/24.
//

import Foundation
import SwiftSoup

struct QuiltRuntime: MinecraftRuntime {
    let type: GameType = .quilt
    let version: GameVersion
    let url: URL
    let name: String
    
    var executableName: String {
        "quilt_installer.jar"
    }
    
    var installCommands: [String] {
        [
            "WORKDIR /tmp",
            "ADD \"\(url.absoluteString)\" ./\(executableName)",
            "RUN java -jar \(executableName) install server \(version) --install-dir=\(MinecraftRuntimeDefaults.homeDirectory) --download-server",
            "WORKDIR \(MinecraftRuntimeDefaults.homeDirectory)",
            "RUN rm -rf /tmp"
        ]
    }
    
    var startCommand: String {
        "java $(cat user_jvm_args.txt) -jar quilt-server-launch.jar $@"
    }
    
    var mappedVolumes: [String] {
        var volumes = MinecraftRuntimeDefaults.mappedVolumes
        volumes.append("mods")
        return volumes
    }
    
    let javaVersion: JavaVersion?
}

/// https://quiltmc.org/en/
final class QuiltRuntimeProvider: MinecraftRuntimeProvider {
    private static let versionListURL = URL(string: "https://maven.quiltmc.org/repository/release/org/quiltmc/quilt-installer/")!
    
    let session: URLSession
    private let vanillaProvider: VanillaRuntimeProvider
    
    init(session: URLSession) {
        self.session = session
        vanillaProvider = VanillaRuntimeProvider(session: session)
    }
    
    private var latestInstaller: QuiltVersion {
        get async throws {
            // Since Quilt uses a universal installer, just download the latest version
            let (data, response) = try await session.data(for: Self.versionListURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MinecraftDockerError.serverDownload("Server error when retrieving the quilt versions")
            }
            guard let content = String(data: data, encoding: .utf8) else {
                throw MinecraftDockerError.serverDownload("Failed to decode server response")
            }
            guard httpResponse.statusCode == 200 else {
                throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the quilt versions: \(content)")
            }
            guard let quilt = QuiltVersion.latestVersion(from: content) else {
                throw MinecraftDockerError.serverDownload("No quilt installer found")
            }
            return quilt
        }
    }
    
    var availableVersions: [GameVersion] {
        get async throws {
            // Quilt only has one universal installer, so the supported versions are the same as Vanilla?
            try await vanillaProvider.availableVersions
        }
    }
    
    func runtime(for version: GameVersion) async throws -> any MinecraftRuntime {
        let installer = try await latestInstaller
        return QuiltRuntime(
            version: version,
            url: installer.installerUrl(base: Self.versionListURL),
            name: "\(version.minecraft)-\(GameType.quilt.rawValue)_\(installer.version)",
            javaVersion: .init(rawValue: try await vanillaProvider.info(for: version).javaVersion)
        )
    }
}

// MARK: - Data model

struct QuiltVersion {
    let version: String
    
    func url(base: URL) -> URL {
        base.appendingPathComponent(version)
    }
    
    func installerUrl(base: URL) -> URL {
        url(base: base).appendingPathComponent("quilt-installer-\(version).jar")
    }
    
    static func latestVersion(from html: String) -> QuiltVersion? {
        // versions are ordered
        versions(from: html).last
    }
    
    static func versions(from html: String) -> [QuiltVersion] {
        guard let document = try? SwiftSoup.parse(html) else { return [] }
        /**
         <body>
            <h1>repository/release/org/quiltmc/quilt-installer/</h1>
            <a href="../">../</a>
            <p>
                <a href="0.3.1/">0.3.1/</a>
            </p>
            [...]
         </body>
         */
        let versionList = try? document.body()?
            .select("p")
        let versions = versionList?.array() ?? []
        
        return versions.compactMap {
            guard let aLink = try? $0.select("a"),
                  aLink.hasAttr("href"),
                  let versionName = try? aLink.text(),
                  versionName.hasSuffix("/"),
                  !versionName.contains("native")
            else {
                return nil
            }
            return QuiltVersion(
                version: versionName.replacingOccurrences(of: "/", with: "")
            )
        }
    }
}
