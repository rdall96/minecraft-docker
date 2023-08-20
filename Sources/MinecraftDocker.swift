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
        ListCommand.self,
        DownloadCommand.self,
        BuildCommand.self,
    ]
}
