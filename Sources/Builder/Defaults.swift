//
//  Defaults.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

enum MinecraftRuntimeDefaults {
    static let homeDirectory = "/minecraft"
    
    static let startupScriptName = "start_server.bash"
    
    static let configurationsDirectory = "\(homeDirectory)/configurations"
    
    static let serverPort: UInt = 25565
    
    static let mappedVolumes: [String] = [
        "world", "configurations"
    ]
    
    static let serverProperties: [String] = [
        "allow-flight",
        "allow-nether",
        "difficulty",
        "enable-command-block",
        "enable-status",
        "enable-query",
        "enforce-secure-profile",
        "gamemode",
        "generate-structures",
        "hardcore",
        "hide-online-players",
        "level-seed",
        "level-type",
        "max-players",
        "max-tick-time",
        "max-world-size",
        "motd",
        "online-mode",
        "op-permission-level",
        "player-idle-timeout",
        "pvp",
        "resource-pack",
        "resource-pack-prompt",
        "require-resource-pack",
        "simulation-distance",
        "spawn-animals",
        "spawn-monsters",
        "spawn-npcs",
        "spawn-protection",
        "view-distance",
        "white-list",
    ]
}
