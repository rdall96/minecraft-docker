//
//  GameVersionOptions.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser

struct GameVersionOptions: ParsableArguments {
    
    @Option(name: .shortAndLong, help: "The type of Minecraft server.")
    var type: GameType = .vanilla
    
    @Option(name: .shortAndLong, help: "The game version to use (i.e.: 1.20.1). \"latest\" and \"all\" are also valid options. For modded Minecraft, you can specify the mod loader version like so <minecraft_version>:<mod_loader_version_string>")
    var version: GameVersion = .latest
    
    func validate() throws {
        if version.minecraft.isEmpty {
            throw ValidationError("The Minecraft version cannot be empty")
        }
        // only some types support specifying a custom mod loader version
        if version.modLoader != nil {
            switch type {
            case .fabric, .forge:
                break
            default:
                throw ValidationError("Specifying a mod loader version is not supported for \(type.rawValue)")
            }
        }
    }
    
    var description: String {
        "Minecraft \(type), version \(version)"
    }
}
