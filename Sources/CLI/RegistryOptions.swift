//
//  RegistryOptions.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

struct RegistryOptions: ParsableArguments {
    
    // NOTE: Disabled until the DockerSwiftAPI library supports querying repositories other than DockerHub
//    @Option(name: .shortAndLong, help: "The remote registry server. Leave blank to indicate DockerHub.")
//    var server: Docker.Registry = .dockerHub
    
    @Option(name: .shortAndLong, help: "Username to log into the remote server.")
    var username: String? = nil
    
    @Option(name: .shortAndLong, help: "Password for the user at the remote server.")
    var password: String? = nil
    
    func validate() throws {
//        if server.isValid {
//            throw ValidationError("Invalid remote server: \(server)")
//        }
        if let username, username.isEmpty {
            throw ValidationError("The username cannot be empty")
        }
        if let password, password.isEmpty {
            throw ValidationError("The password cannot be empty")
        }
    }
}
