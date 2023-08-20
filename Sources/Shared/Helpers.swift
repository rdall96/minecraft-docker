//
//  Helpers.swift
//
//
//  Created by Ricky Dall'Armellina on 8/20/23.
//

import Foundation

func runFunctionAndTrack(_ function: () async throws -> Void) async throws {
    let referenceTime: Date = .now
    try await function()
    let timeElapsedDescription = String(format: "%.1f second(s)", abs(referenceTime.timeIntervalSinceNow))
    MinecraftDockerLog.info("Time elapsed: \(timeElapsedDescription)")
}
