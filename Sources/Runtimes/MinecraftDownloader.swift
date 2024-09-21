//
//  MinecraftDownloader.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MinecraftDownloader {
    
    let session: URLSession
    let runtimeProvider: MinecraftRuntimeProvider
    
    init(type: MinecraftType, session: URLSession = URLSession(configuration: .default)) {
        self.session = session
        switch type {
        case .vanilla:
            runtimeProvider = VanillaRuntimeProvider(session: session)
        case .fabric:
            runtimeProvider = FabricRuntimeProvider(session: session)
        case .forge:
            runtimeProvider = ForgeRuntimeProvider(session: session)
        case .neoForged:
            runtimeProvider = NeoForgedRuntimeProvider(session: session)
        }
    }
    
    /// Download a specific Minecraft version to the provided path, and return the full path to the downloaded file
    @discardableResult
    func download(version: MinecraftVersion, to path: URL) async throws -> URL {
        let runtime = try await runtimeProvider.runtime(for: version)
        let (downloadPath, serverDownloadResponse) = try await session.download(from: runtime.url)
        guard let httpResponse = serverDownloadResponse as? HTTPURLResponse else {
            throw MinecraftDockerError.serverDownload("Server error when retrieving the download information for version: \(version)")
        }
        guard httpResponse.statusCode == 200 else {
            throw MinecraftDockerError.serverDownload("Server responded with an error when fetching the version (\(version)) information")
        }
        
        // save the data to disk
        let serverExecutablePath = path.appendingPathComponent("minecraft_server_\(runtime.name).jar")
        do {
            try FileManager.default.moveItem(at: downloadPath, to: serverExecutablePath)
        }
        catch {
            throw MinecraftDockerError.serverDownload("Failed to write downloaded server jar to disk at: \(serverExecutablePath.path)")
        }
        
        return serverExecutablePath
    }
}
