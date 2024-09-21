//
//  MinecraftType.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

// MARK: - Minecraft Version

struct MinecraftVersion: Equatable, CustomStringConvertible {
    let rawValue: String
    
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    var description: String { rawValue }
    
    var components: [UInt] {
        guard self != .latest else { return [] }
        return rawValue.split(separator: ".")
            .compactMap { UInt($0) }
    }
    
    static let latest: Self = .init("latest")
    static let all: Self = .init("all")
}

extension MinecraftVersion: Comparable {
    static func < (lhs: MinecraftVersion, rhs: MinecraftVersion) -> Bool {
        // i.e.: 1.20.1 < 1.8.2
        
        // if either is latest, then it's newer
        if lhs == .latest, rhs != .latest { return false } // latest < 1.20
        if lhs != .latest, rhs == .latest { return true } // 1.20 < latest
        if lhs == .latest, rhs == .latest { return false } // latest < latest
        
        // need at least two components for each
        let lhsComponents = lhs.components
        let rhsComponents = rhs.components
        guard lhsComponents.count >= 2, rhsComponents.count >= 2 else { return false }
        
        // major version
        if lhsComponents[0] < rhsComponents[0] { return true } // 1.2.3 < 2.5.7
        if lhsComponents[0] > rhsComponents[0] { return false } // 2.1 < 1.5.2
        
        // minor version
        if lhsComponents[1] < rhsComponents[1] { return true } // 1.2.5 < 1.4.7
        if lhsComponents[1] > rhsComponents[1] { return false } // 1.12.1 < 1.8
        
        // patch version
        if lhsComponents.count == 3, rhsComponents.count == 2 { return false } // 1.19.1 < 1.19
        if lhsComponents.count == 2, rhsComponents.count == 3 { return true } // 1.20 < 1.20.1
        return lhsComponents[2] < rhsComponents[2] // 1.14.2 < 1.14.3
    }
}

extension MinecraftVersion: ExpressibleByArgument {
    init?(argument: String) {
        self = .init(argument)
    }
}

// MARK: - Minecraft Type

enum MinecraftType: String, CustomStringConvertible {
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

extension MinecraftType: ExpressibleByArgument {}
