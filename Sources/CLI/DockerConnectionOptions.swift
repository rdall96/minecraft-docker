//
//  DockerConnectionOptions.swift
//  MinecraftDocker
//
//  Created by Ricky Dall'Armellina on 11/22/25.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

struct DockerConnectionOptions: ParsableArguments {

    enum ConnectionType: String, ExpressibleByArgument {
        case socket
        case server
    }

    @Option(name: .shortAndLong, help: "The type of Docker connection to use")
    var dockerConnectionType: ConnectionType = .socket

    @Option(name: .long, help: "The Docker server host to communicate with when the connection type is 'server'.")
    var dockerServerHost: String = "https://localhost:2376"

    @Option(name: .long, help: "Path to the Docker public certificate PEM. Used when the connection type is 'server'.")
    var dockerCert: String = ""

    @Option(name: .long, help: "Path to the Docker public key PEM. Used when the connection type is 'server'.")
    var dockerKey: String = ""

    @Option(name: .long, help: "Path to the Docker CA certificate PEM. Used when the connection type is 'server'.")
    var dockerCACert: String = ""

    func validate() throws {
        // only needs to validate if the connection type is server
        guard case .server = dockerConnectionType else {
            return
        }
        guard URL(string: dockerServerHost) != nil else {
            throw ValidationError("Invalid Docker server host.")
        }
        guard FileManager.default.fileExists(atPath: dockerCert), URL(string: dockerCert) != nil else {
            throw ValidationError("A Docker certificate path is required when the connection type is 'server'.")
        }
        guard FileManager.default.fileExists(atPath: dockerKey), URL(string: dockerKey) != nil else {
            throw ValidationError("A Docker public key path is required when the connection type is 'server'.")
        }
        guard FileManager.default.fileExists(atPath: dockerCACert), URL(string: dockerCACert) != nil else {
            throw ValidationError("A Docker CA certificate path is required when the connection type is 'server'.")
        }
    }

    var description: String {
        switch dockerConnectionType {
        case .socket: "Docker Socket"
        case .server: "Docker Server"
        }
    }
}

extension DockerConnectionOptions {
    var client: DockerClient {
        switch dockerConnectionType {
        case .socket: DockerClient(connection: .defaultSocket)
        case .server: DockerClient(connection: .server(.init(
            url: URL(string: dockerServerHost)!,
            clientKeyPEM: URL(string: dockerKey)!,
            clientCertificatePEM: URL(string: dockerCert)!,
            trustRootCertificatePEM: URL(string: dockerCACert)!
        )))
        }
    }
}
