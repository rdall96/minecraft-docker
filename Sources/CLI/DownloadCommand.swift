//
//  DownloadCommand.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser

struct DownloadCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download a Minecraft server version."
    )
    
    @OptionGroup
    var minecraft: GameVersionOptions
    
    @Flag(name: .shortAndLong, help: "Only list out the available server versions for the given minecraft server type.")
    var list: Bool = false
    
    @Option(name: [.customShort("o"), .customLong("output")], help: "Directory where to download the server executable. If the directory doesn't exist, it will be created. If it's unspeccified, the file will be saved in the current directory.")
    var path: String? = nil
    
    func validate() throws {
        // validate the download path
        if let path, resolvedPath(for: path) == nil {
            throw ValidationError("Invalid download path \(path)")
        }
    }
    
    func run() async {
        let downloader = MinecraftDownloader(for: minecraft.type)
        
        // list the versions and quit if specified
        if list {
            MinecraftDockerLog.log("Listing available versions for Minecraft \(minecraft.type)")
            do {
                var versions = try await downloader.runtimeProvider.availableVersions
                    .sorted(by: >)
                guard !versions.isEmpty else {
                    MinecraftDockerLog.error("No available Minecraft server versions found for \(minecraft.type)")
                    return
                }
                // add the latest tag to the first version
                versions[0] = .init(minecraft: versions[0].description + " (latest)")
                let versionsList = versions.map({ $0.description }).joined(separator: ", ")
                MinecraftDockerLog.log("Available Minecraft versions for \(minecraft.type): \(versionsList)")
            }
            catch {
                MinecraftDockerLog.error("An error occurred fetching the available Minecraft versions: \(error)")
            }
            return
        }
        
        // If the version is `latest`, find it
        var downloadVersion = minecraft.version
        if downloadVersion == .latest {
            MinecraftDockerLog.info("Selected version 'latest', will attempt to retrieve the version name")
            do {
                downloadVersion = try await downloader.runtimeProvider.availableVersions.first!
            }
            catch {
                MinecraftDockerLog.error(error.localizedDescription)
                return
            }
        }
        
        // if the path is nil, then use the current directory
        let pathUrl: URL
        if let path {
            pathUrl = resolvedPath(for: path)! // this was alredy validated
            // create the directory if it doesn't exist
            do {
                try FileManager.default.createDirectory(at: pathUrl, withIntermediateDirectories: true)
                MinecraftDockerLog.info("Created download path at\(pathUrl.path)")
            }
            catch {
                MinecraftDockerLog.error("Failed to create directory at \(pathUrl.path): \(error)")
                return
            }
        }
        else {
            pathUrl = URL(string: FileManager.default.currentDirectoryPath)! // this should always work
        }
        
        // download the executable
        MinecraftDockerLog.log("Downloading Minecraft \(downloadVersion) with \(downloader.runtimeProvider.self)...")
        do {
            try await runFunctionAndTrack {
                let serverUrl = try await downloader.download(version: downloadVersion, to: pathUrl)
                MinecraftDockerLog.log("Server executable (\(minecraft.type.rawValue)-\(minecraft.version)) downloaded at: \(serverUrl.path)")
            }
        }
        catch {
            MinecraftDockerLog.error("Download failed: \(error)")
            return
        }
    }
}
