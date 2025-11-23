//
//  BuildCommand.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import ArgumentParser
import DockerSwiftAPI

struct BuildCommand: AsyncParsableCommand {
    private static let defaultImageName = "rdall96/minecraft-server"

    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build a Minecraft server docker image. If credentials are specified, the image will also be uploaded to DockerHub."
    )

    @OptionGroup
    var dockerConnection: DockerConnectionOptions

    @Option(name: .shortAndLong, help: "Name of the Docker image to create. Default: \(Self.defaultImageName)")
    var name: String = Self.defaultImageName

    @OptionGroup
    var minecraft: GameVersionOptions
    
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

    private var dockerClient: DockerClient {
        let client = dockerConnection.client

        // this was already validated, so it should never happen, but we need to handle the case anyway
        if let username = registry.username,
           let password = registry.password {
            client.authentication = .init(username: username, password: password)
        }

        return client
    }

    private func push(_ image: Docker.Image) async throws {
        // we don't want to override existing images, unless we are told to do so (option: `force`).
        // check if any of the tags to push already exist on the remote, and if they do, don't push the image.
        // NOTE: we never tag the same image more than once with the exception of `latest`.
        let tagToPush = image.tags.first { !$0.isLatest }
        guard let tagToPush else {
            MinecraftDockerLog.error("No tags found for image \(image.id). Ignoring push.")
            throw MinecraftDockerError.pushFailed
        }

        // FIXME: Make the remote registry configurable
        let remoteTags = try await DockerHub.tags(for: "minecraft-server", in: "rdall96")

        if !force, remoteTags.contains(where: { $0.name == tagToPush.tag }) {
            throw MinecraftDockerError.remoteTagExists
        }

        // Push every tag
        for tag in image.tags {
            try await recordRuntime(of: "Push (\(tag))") {
                try await dockerClient.push(image, tag: tag)
                MinecraftDockerLog.log("Pushed \(tag)")
            }
        }
    }
    
    private func clean(images: [Docker.Image]) async throws -> UInt {
        var removedCount: UInt = 0
        for image in images {
            try await dockerClient.remove(image, force: true)
            removedCount += 1
        }
        return removedCount
    }
    
    private func build(version: GameVersion, with builder: MinecraftBuilder, tagLatest: Bool = false) async -> Docker.Image? {
        MinecraftDockerLog.info("Building version \(version) ...")
        do {
            return try await recordRuntime(of: "Build (\(version))") {
                let image = try await builder.build(
                    minecraftVersion: version,
                    imageName: name,
                    tagLatest: tagLatest
                )
                MinecraftDockerLog.log("Built \(image)")
                return image
            }
        }
        catch let error as DockerError {
            MinecraftDockerLog.error("\(version) build failed: \(error.localizedDescription)")
            return nil
        }
        catch {
            MinecraftDockerLog.error("An unknown error occurred building \(version): \(error.localizedDescription)")
            return nil
        }
    }
    
    func run() async throws {
        MinecraftDockerLog.log("Building \(minecraft.description)")
        
        // create a builder
        let builder = MinecraftBuilder(for: minecraft.type, with: dockerClient)
        
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
        case .neoForged:
            runtimeProvider = NeoForgedRuntimeProvider(session: session)
        case .quilt:
            runtimeProvider = QuiltRuntimeProvider(session: session)
        }
        var versionsToBuild = [GameVersion]()
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
            throw MinecraftDockerError.invalidGameVersion
        }
        
        // build the images
        var builtImages = [Docker.Image]()
        var failedBuilds: [GameVersion] = []
        // only tag the latest image if we are tracking it (in the imagesToBuild list)
        let possibleLatestImage = hasLatestImage ? versionsToBuild.first : nil
        for version in versionsToBuild.reversed() {
            let builtImage = await build(
                version: version,
                with: builder,
                tagLatest: version == possibleLatestImage
            )
            if let builtImage {
                builtImages.append(builtImage)
            }
            else {
                failedBuilds.append(version)
            }
        }
        if builtImages.isEmpty {
            MinecraftDockerLog.error("No images were built!")
        }
        else {
            MinecraftDockerLog.log("Built \(builtImages.count) image(s)!")
        }
        if !failedBuilds.isEmpty {
            MinecraftDockerLog.warning("Failed builds: \(failedBuilds.map(\.description).joined(separator: ", "))")
            throw MinecraftDockerError.buildError("Some images failed to build")
        }

        // push
        if push {
            MinecraftDockerLog.log("Will push \(builtImages.count) image(s) to remote")
            for image in builtImages {
                do {
                    try await push(image)
                }
                catch MinecraftDockerError.remoteTagExists {
                    MinecraftDockerLog.warning("\(image) already exists in the registry, skipping push")
                }
                catch let error as DockerError {
                    MinecraftDockerLog.error("Failed to push \(image) to registry: \(error.localizedDescription)")
                }
                catch {
                    MinecraftDockerLog.error("An unknown error occurred when pushing \(image): \(error)")
                }
            }
        }
        
        // clean
        if clean {
            MinecraftDockerLog.log("Removing build artifacts")
            do {
                let removedCount = try await clean(images: builtImages)
                MinecraftDockerLog.info("Removed \(removedCount) built image(s)")
            }
            catch let error as DockerError {
                MinecraftDockerLog.error("Cleanup failed: \(error.localizedDescription)")
                throw MinecraftDockerError.cleanupFailed
            }
            catch {
                MinecraftDockerLog.error("An unknown error occurred: \(error)")
                throw MinecraftDockerError.cleanupFailed
            }
        }
    }
}

fileprivate extension Docker.Image.Tag {
    /// This tag contains the keyword `latest` indicating it's the newest tag for a givne image.
    var isLatest: Bool { tag.contains("latest") }
}
