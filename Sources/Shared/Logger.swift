//
//  Logger.swift
//
//
//  Created by Ricky Dall'Armellina on 8/12/23.
//

import Foundation
import Logging

struct MinecraftDockerLog {
    private static let shared = MinecraftDockerLog()
    
    let logger: Logger
    
    private init() {
        logger = Logger(label: "minecraft-docker")
    }
    
    static func info(_ message: String) {
        shared.logger.info("\(message)")
    }
    
    static func log(_ message: String) {
        shared.logger.notice("\(message)")
    }
    
    static func warning(_ message: String) {
        shared.logger.warning("\(message)")
    }
    
    static func error(_ message: String) {
        shared.logger.error("\(message)")
    }
    
    static func critical(_ error: MinecraftDockerError) {
        shared.logger.critical("\(error)")
    }
}
