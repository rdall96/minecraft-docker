//
//  ListCommand.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ListCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available Minecraft server versions."
    )
    
    @Option(name: [.customShort("t"), .customLong("type")], help: "The type of Minecraft server to download.")
    var type: MinecraftType
    
    func run() async {
        let session = URLSession(configuration: .default)
        let runtimeProvider: MinecraftRuntimeProvider
        switch type {
        case .vanilla:
            runtimeProvider = VanillaRuntimeProvider(session: session)
        case .fabric:
            runtimeProvider = FabricRuntimeProvider(session: session)
        case .forge:
            runtimeProvider = ForgeRuntimeProvider(session: session)
        }
        MinecraftDockerLog.log("Listing available versions for Minecraft \(type)")
        
        do {
            var versions = try await runtimeProvider.availableVersions
                .sorted(by: >)
            guard !versions.isEmpty else {
                MinecraftDockerLog.error("No available Minecraft server versions found for \(type.description)")
                return
            }
            // add the latest tag to the first version
            versions[0] = .init(versions[0].rawValue + " (latest)")
            let versionsList = versions.map({ $0.rawValue }).joined(separator: ", ")
            MinecraftDockerLog.log("Available Minecraft versions for \(type.description): \(versionsList)")
        }
        catch {
            MinecraftDockerLog.error("An error occurred fetching the available Minecraft versions: \(error)")
        }
    }
}
