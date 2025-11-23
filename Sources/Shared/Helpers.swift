//
//  Helpers.swift
//
//
//  Created by Ricky Dall'Armellina on 8/20/23.
//

import Foundation

func recordRuntime<T>(of function: String, task: @escaping () async throws -> T) async throws -> T {
    let referenceTime: Date = .now
    let result = try await task()
    let timeElapsedDescription = String(format: "%.1f second(s)", abs(referenceTime.timeIntervalSinceNow))
    MinecraftDockerLog.info("\(function) - Time elapsed: \(timeElapsedDescription)")
    return result
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
