//
//  MinecraftVersionOptions.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser

struct MinecraftVersionOptions: ParsableArguments {
    
    @Option(name: .shortAndLong, help: "The type of Minecraft server.")
    var type: MinecraftType = .vanilla
    
    @Option(name: .shortAndLong, help: "The game version to use (i.e.: 1.20.1). \"latest\" and \"all\" are also valid options.")
    var version: MinecraftVersion = .latest
    
    func validate() throws {
        if version.rawValue.isEmpty {
            throw ValidationError("The Minecraft version cannot be empty")
        }
    }
    
    var description: String {
        "Minecraft \(type), version \(version)"
    }
}
