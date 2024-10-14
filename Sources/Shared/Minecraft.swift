//
//  Minecraft.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

// MARK: - Game Version

struct GameVersion: Equatable, CustomStringConvertible {
    let minecraft: String
    let modLoader: String? // optionally specify the mod loader version
    
    init(minecraft: String, modLoader: String? = nil) {
        self.minecraft = minecraft
        self.modLoader = modLoader
    }
    
    var description: String {
        var string = minecraft
        if let modLoader {
            string += ":\(modLoader)"
        }
        return string
    }
    
    var minecraftVersionComponents: [UInt] {
        guard self != .latest else { return [] }
        return minecraft.split(separator: ".")
            .compactMap { UInt($0) }
    }
    
    var modLoaderVersionComponents: [UInt]? {
        guard self != .latest else { return [] }
        return modLoader?.split(separator: ".")
            .compactMap { UInt($0) }
    }
    
    static let latest: Self = .init(minecraft: "latest")
    static let all: Self = .init(minecraft: "all")
}

extension GameVersion: Comparable {
    
    private enum VersionCompareResult {
        case lessThan
        case greaterThan
        case equal
    }
    
    private static func compare(lhs: String, rhs: String) -> VersionCompareResult {
        let lhsComponents = lhs.versionComponents
        let rhsComponents = rhs.versionComponents
        
        // major version
        if lhsComponents[0] < rhsComponents[0] { return .lessThan } // 1.2.3 < 2.5.7
        else if lhsComponents[0] > rhsComponents[0] { return .greaterThan } // 2.1 < 1.5.2
        
        // minor version
        if lhsComponents[1] < rhsComponents[1] { return .lessThan } // 1.2.5 < 1.4.7
        else if lhsComponents[1] > rhsComponents[1] { return .greaterThan } // 1.12.1 < 1.8
        
        // patch version
        if lhsComponents[2] < rhsComponents[2] { return .lessThan } // 1.14.2 < 1.14.3
        else if lhsComponents[2] > rhsComponents[2] { return .greaterThan } // 1.14.2 < 1.14.3
        else { return .equal }
    }
    
    static func < (lhs: GameVersion, rhs: GameVersion) -> Bool {
        // minecraft version
        let minecraftVersionComparison = compare(lhs: lhs.minecraft, rhs: rhs.minecraft)
        if case .lessThan = minecraftVersionComparison { return true }
        else if case .greaterThan = minecraftVersionComparison { return false }
        
        // mod loader version (if one is nil, that's latest)
        let modLoaderVersionComparison = compare(
            lhs: lhs.modLoader ?? "latest",
            rhs: rhs.modLoader ?? "latest"
        )
        return modLoaderVersionComparison == .lessThan
    }
}

extension GameVersion: ExpressibleByArgument {
    init?(argument: String) {
        if argument.contains(":") {
            let version = argument.split(separator: ":").compactMap { String($0) }
            self.init(minecraft: version[0], modLoader: version.last)
        }
        else {
            self.init(minecraft: argument)
        }
    }
}

fileprivate extension String {
    var versionComponents: [UInt] {
        if self == "latest" {
            return [.max, 0, 0]
        }
        else {
            var components = split(separator: ".").compactMap { String($0) }
            if components.count == 2 {
                components.append("0")
            }
            return components.compactMap { UInt($0) }
        }
    }
}

// MARK: - Game Type

enum GameType: String, CustomStringConvertible {
    case vanilla
    case fabric
    case forge
    case neoForged
    case quilt
    
    var description: String {
        switch self {
        case .vanilla:
            return "Java edition (vanilla)"
        case .fabric:
            return "Modded Java with the Fabric mod loader"
        case .forge:
            return "Modded Java with the Forge mod loader"
        case .neoForged:
            return "Modded Java with the NeoForged mod loader"
        case .quilt:
            return "Modded Java with the Quilt mod loader"
        }
    }
    
    /// Name of the `latest` image tag for this type of Minecraft
    var latestTag: Docker.Tag {
        if self == .vanilla { return .init("latest") }
        else {
            return .init("\(rawValue)_latest")
        }
    }
}

extension GameType: ExpressibleByArgument {}
