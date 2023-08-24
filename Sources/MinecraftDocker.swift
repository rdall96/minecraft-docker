// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

@main
struct MinecraftDocker: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "Minecraft Docker CLI",
        subcommands: commands
    )
    
    static private let commands: [ParsableCommand.Type] = [
        VersionCommand.self,
        
        // TODO: Create a list command to show running containers when the DockerSwiftAPI library supports the running image in the `Docker.Container` model
        DownloadCommand.self,
        BuildCommand.self,
        RunCommand.self,
    ]
}
