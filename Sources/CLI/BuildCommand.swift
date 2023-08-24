//
//  BuildCommand.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct BuildCommand: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build a Minecraft server docker image. If credentials are specified, the image will also be uploaded to DockerHub."
    )
    
    @Option(name: .shortAndLong, help: "Name of the Docker image to create.")
    var name: String = "rdall96/minecraft-server"
    
    @OptionGroup
    var minecraft: MinecraftVersionOptions
    
    @OptionGroup
    var registry: RegistryOptions
    
    @Flag(help: "Push the image to the registry after building. This requires a remote registry and credentials.")
    var push: Bool = false
    
    @Flag(name: .shortAndLong, help: "Force push the image to the registry.")
    var force: Bool = false
    
    @Flag(help: "Remove artifacts after the task is completed.")
    var clean: Bool = false
    
    func validate() throws {
        // iamge name validation
        if name.isEmpty { throw ValidationError("The image name cannot be empty") }
        if name.split(separator: "/").count > 2 { throw ValidationError("The image name is invalid. Only one '/' is allowed.") }
        
        // push requires remote registry options
        if push {
            guard let username = registry.username, !username.isEmpty,
                 let password = registry.password, !password.isEmpty
            else {
                throw ValidationError("Using the `push` setting requires a username and password for the remote registry")
            }
        }
    }
    
    private func login() async throws {
        guard let username = registry.username,
              let password = registry.password
        else {
            // this was already validated, so it should never happen, but we need to handle the case anyway
            fatalError("Expected server, username, and password for push action")
        }
        try await Docker.login(username: username, password: password)
        MinecraftDockerLog.log("Successfully logged into remote repository as \(username)")
    }
    
    private func push(image: Docker.Image) async {
        do {
            MinecraftDockerLog.info("Pushing \(image.description)")
            try await Docker.push(image)
            MinecraftDockerLog.log("Pushed \(image.description) to remote")
        }
        catch let error as DockerError {
            MinecraftDockerLog.error("Failed to push \(image.description) to remote repository: \(error.errorDescription)")
        }
        catch {
            MinecraftDockerLog.error("An unknown error occurred: \(error)")
        }
    }
    
    private func push(images: [Docker.Image]) async throws {
        // cache the existing tags
        let imageComponenets = name.split(separator: "/").map({ String($0) })
        guard let repositoryNamespace = imageComponenets.first else {
            MinecraftDockerLog.critical(.missingRepositoryNamespace)
            throw MinecraftDockerError.missingRepositoryNamespace
        }
        guard let repopsitoryName = imageComponenets.last else {
            MinecraftDockerLog.critical(.missingRepositoryName)
            throw MinecraftDockerError.missingRepositoryName
        }
        let repository = try await DockerHub.repositories(for: repositoryNamespace).first {
            $0.name == repopsitoryName
        }!
        let existingTags = try await DockerHub.tags(for: repository)
        
        // push images
        for image in images {
            // if we have `force` just push the image
            if force {
                MinecraftDockerLog.info("Force push is set, pushing image \(image.description)")
                await push(image: image)
                continue
            }
            // otherwise check if it already exists in the remote repo
            if !existingTags.filter({ $0.name == image.tag.name }).isEmpty {
                MinecraftDockerLog.warning("Remote tag \(image.description) already exists! Ignoring.")
                continue
            }
            await push(image: image)
        }
    }
    
    private func clean(images: [Docker.Image]) async throws -> UInt {
        var removedCount: UInt = 0
        for image in images {
            try await Docker.remove(image: image)
            removedCount += 1
        }
        return removedCount
    }
    
    private func build(version: MinecraftVersion, with builder: MinecraftBuilder, tagLatest: Bool = false) async -> [Docker.Image] {
        MinecraftDockerLog.info("Building version \(version) ...")
        do {
            var images = [Docker.Image]()
            try await runFunctionAndTrack {
                images = try await builder.build(
                    minecraftVersion: version,
                    imageName: name,
                    tagLatest: tagLatest
                )
            }
            if images.isEmpty {
                MinecraftDockerLog.error("Fatal! Build succeeded but produced no images")
                throw MinecraftDockerError.buildError("No images were built")
            }
            MinecraftDockerLog.log("Build successful! Artifacts: \(images.map({ $0.description }).joined(separator: ", "))")
            return images
        }
        catch let error as DockerError {
            MinecraftDockerLog.error("Build failed: \(error.errorDescription)")
            return []
        }
        catch {
            MinecraftDockerLog.error("An unknown error occurred: \(error)")
            return []
        }
    }
    
    func run() async throws {
        MinecraftDockerLog.log("Building \(minecraft.description)")
        
        // If this run will require a push, try to login before building anything
        if push {
            do {
                try await login()
            }
            catch let error as DockerError {
                MinecraftDockerLog.error("Failed to log into remote repository: \(error.errorDescription)")
                throw MinecraftDockerError.loginFailed
            }
            catch {
                MinecraftDockerLog.error("An unknown error occurred: \(error)")
                throw MinecraftDockerError.loginFailed
            }
        }
        
        // create a builder
        let builder = MinecraftBuilder(minecraftType: minecraft.type)
        
        // if "all" is specified as the version, we need to cache all the versions to build and call them in succession
        let session = URLSession(configuration: .default)
        let runtimeProvider: MinecraftRuntimeProvider
        switch minecraft.type {
        case .vanilla:
            runtimeProvider = VanillaRuntimeProvider(session: session)
        case .fabric:
            runtimeProvider = FabricRuntimeProvider(session: session)
        case .forge:
            runtimeProvider = ForgeRuntimeProvider(session: session)
        }
        var versionsToBuild = [MinecraftVersion]()
        var hasLatestImage = false // track if we are going to be be building the latest image, so we can choose to tag it later
        if minecraft.version == .all {
            versionsToBuild = (try? await runtimeProvider.availableVersions) ?? []
            hasLatestImage = true
        }
        else if minecraft.version == .latest {
            if let version = try? await runtimeProvider.latestVersion {
                versionsToBuild = [version]
                hasLatestImage = true
            }
        }
        else {
            versionsToBuild = [minecraft.version]
            // this could be the latest version if one were to specify it manually
            // we're not going to tag it as `latest` because a manual build is likely intentional to only build a specific version
        }
        if versionsToBuild.isEmpty {
            MinecraftDockerLog.error("No versions to build provided!")
            throw MinecraftDockerError.invalidMinecraftVersion
        }
        
        // build the images
        var builtImages = [Docker.Image]()
        // only tag the latest image if we are tracking it (in the imagesToBuild list)
        let possibleLatestImage = hasLatestImage ? versionsToBuild.first : nil
        for version in versionsToBuild.reversed() {
            let builtImage = await build(
                version: version,
                with: builder,
                tagLatest: version == possibleLatestImage
            )
            builtImages.append(contentsOf: builtImage)
        }
        
        // push
        if push {
            MinecraftDockerLog.log("Will push \(builtImages.count) image(s) to remote")
            do {
                try await runFunctionAndTrack {
                    try await push(images: builtImages)
                }
            }
            catch let error as DockerError {
                MinecraftDockerLog.error("Failed to push (some) image(s) to remote: \(error.errorDescription)")
                throw MinecraftDockerError.pushFailed
            }
            catch {
                MinecraftDockerLog.error("An unknown error occurred: \(error)")
                throw MinecraftDockerError.pushFailed
            }
        }
        
        // clean
        if clean {
            MinecraftDockerLog.info("Removing built artifacts")
            do {
                let removedCount = try await clean(images: builtImages)
                MinecraftDockerLog.log("Removed \(removedCount) built image(s)")
            }
            catch let error as DockerError {
                MinecraftDockerLog.error("Cleanup failed: \(error.errorDescription)")
                throw MinecraftDockerError.cleanupFailed
            }
            catch {
                MinecraftDockerLog.error("An unknown error occurred: \(error)")
                throw MinecraftDockerError.cleanupFailed
            }
        }
    }
}
