//
//  Exceptions.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import DockerSwiftAPI

enum MinecraftDockerError: Error {
    case serverDownload(String?)
    case invalidGameVersion
    case dockerError(DockerError?)
    case buildError(String)
    case remoteTagExists
    case missingRepositoryNamespace
    case missingRepositoryName
    case loginFailed
    case pushFailed
    case cleanupFailed
}
