//
//  Helpers.swift
//
//
//  Created by Ricky Dall'Armellina on 8/20/23.
//

import Foundation

func runFunctionAndTrack(_ function: @escaping () async throws -> Void) async throws {
    let referenceTime: Date = .now
    try await function()
    let timeElapsedDescription = String(format: "%.1f second(s)", abs(referenceTime.timeIntervalSinceNow))
    MinecraftDockerLog.info("Time elapsed: \(timeElapsedDescription)")
}

func resolvedPath(for string: String) -> URL? {
    // expand th user directory if necessary
    if string.contains("~") {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(string.replacingOccurrences(of: "~/", with: ""))
    }
    else {
        return URL(string: string)
    }
}
