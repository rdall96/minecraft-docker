//
//  VersionCommand.swift
//
//
//  Created by Ricky Dall'Armellina on 8/24/23.
//

import Foundation
import ArgumentParser

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show the CLI version."
    )
    
    func run() throws {
        // if this is running in the docker context, there's a "version" file at the current working directory,
        // otherwise, use the in-code version
        var versionString = Version.current.description
        
        if let workingDirectory = URL(string: FileManager.default.currentDirectoryPath) {
            let versionFilePath = workingDirectory.appendingPathComponent("version").path
            if FileManager.default.fileExists(atPath: versionFilePath),
               let versionData = try? String(contentsOfFile: versionFilePath) {
                versionString = versionData.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        print("Minecraft Docker CLI \(versionString)")
    }
}
