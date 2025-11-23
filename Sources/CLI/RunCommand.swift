//
//  RunCommand.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/24/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

/// The run command was removed when the CLI updated to DockerSwiftAPI lib 2.0.0.
//struct RunCommand: AsyncParsableCommand {
//    
//    static let configuration = CommandConfiguration(
//        commandName: "run",
//        abstract: "Run a Minecraft server docker image."
//    )
//    
//    @Option(name: .shortAndLong, help: "Name to assing to the docker container. Will default to the type and version.")
//    var name: String? = nil
//    
//    @OptionGroup
//    var minecraft: GameVersionOptions
//    
//    @Option(name: .shortAndLong, help: "Location where to store the Minecraft world data and other persistent files.")
//    var path: String
//    
//    @Flag(help: "Build the image before running it if it's not found on the system.")
//    var build: Bool = false
//    
//    @Flag(help: "Remove the Docker container after the server stops.")
//    var clean: Bool = false
//    
//    func validate() throws {
//        // the name cannot contain spaces
//        if let name, name.contains(" ") {
//            throw ValidationError("The server name cannto contain spaces")
//        }
//        // make sure the path is valid
//        if resolvedPath(for: path) == nil {
//            throw ValidationError("Invalid server path \(path)")
//        }
//        // only type `vanilla` is supported by the run command because I'm lazy
//        guard minecraft.type == .vanilla else {
//            throw ValidationError("\(minecraft.type.rawValue.capitalized) servers are not supported by the run command, the developer was too lazy to implement it.")
//        }
//        // no `latest` and `all` options are supported by the run command
//        if minecraft.version == .latest || minecraft.version == .all {
//            throw ValidationError("Minecraft version \"\(minecraft.version)\" is not a supported option by the run command. Please specify a version (i.e.: 1.19.2).")
//        }
//    }
//    
//    func run() async throws {
//        // build the image if necessary
//        if build {
//            // don't build the image if it already exists
//            let image = try await DockerImagesRequest.minecraftServerImage(version: minecraft.version)
//            if image != nil {
//                MinecraftDockerLog.log("A Docker image for this server version already exists, will ignore the `--build` argument.")
//            }
//            else {
//                let buildTask = try BuildCommand.parse([
//                    "--type", "\(minecraft.type.rawValue)",
//                    "--version", "\(minecraft.version)"
//                ])
//                try await buildTask.run()
//            }
//        }
//        
//        // make sure the run directory exists
//        let runPathUrl = resolvedPath(for: path)! // this was already validated
//        try FileManager.default.createDirectory(at: runPathUrl, withIntermediateDirectories: true)
//        
//        // get a list of directories to create on the local system - use an empty runtime
//        let gameDirectories = MinecraftRuntimeDefaults.mappedVolumes.compactMap {
//            runPathUrl.appendingPathComponent($0)
//        }
//        for directory in gameDirectories {
//            do {
//                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
//            }
//            catch {
//                MinecraftDockerLog.error("Failed to create persistent directory for game files at \(directory.path): \(error)")
//                return
//            }
//        }
//        
//        do {
//            // FIXME: Needs run behavior for DockerSwiftAPI@2.0.0
//            throw DockerError.unknown
////            let container = try await Docker.run(
////                image: .minecraftServerImage(version: minecraft.version),
////                with: .init(
////                    environment: [.acceptEula], // not support for other environment variables yet, so just accept the EULA
////                    name: name ?? "minecraft-server-\(minecraft.type.rawValue)_\(minecraft.version)",
////                    ports: [.defaults],
////                    removeWhenStopped: clean,
////                    volumes: gameDirectories.enumerated().map { index, directory in
////                        .init(
////                            hostPath: directory.path,
////                            containerPath: "\(MinecraftRuntimeDefaults.homeDirectory)/\(MinecraftRuntimeDefaults.mappedVolumes[index])"
////                        )
////                    }
////                ),
////                pull: false // this will realistically pull anyway if the image really doesn't exist, but in theory it should
////            )
////            MinecraftDockerLog.log("Created container: \(container.name ?? "-")")
//        }
//        catch {
//            MinecraftDockerLog.error("Failed to start Docker container for \(minecraft.description): \(error)")
//        }
//    }
//}
//
//fileprivate extension DockerImagesRequest {
//    private static let minecraftServerImageName: String = "rdall96/minecraft-server"
//
//    static func minecraftServerImage(version: GameVersion) async throws -> Docker.Image? {
//        try await DockerImagesRequest.image(tag: .init(
//            name: Self.minecraftServerImageName,
//            tag: version.description
//        ))
//    }
//}
//
//fileprivate extension Docker.EnvironmentVariable {
//    static var acceptMinecraftEula: Self = .init(key: "EULA", value: "true")
//}
//
//fileprivate extension Docker.Container.PortMap {
//    static var defaultMinecraftPort: Self = .init(hostPort: 25565, containerPort: 25565, type: .tcp)
//}
