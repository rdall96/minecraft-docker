//
//  MinecraftBuilder.swift
//
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation
import DockerSwiftAPI

/// Build a Minecraft docker image
protocol MinecraftBuilderProtocol {
    var minecraftType: GameType { get }
    
    func generateDockerFile(systemPackages: [String], installCommands: [String], volumes: [String]) -> String
    func generateStartupScript(serverProperties: [String], command: String) -> String
    
    func build(minecraftVersion: GameVersion, imageName: String, tagLatest: Bool) async throws -> Docker.Image
}

final class MinecraftBuilder: MinecraftBuilderProtocol {
    private static let baseImageTag = Docker.Image.Tag(name: "alpine", tag: "3.22.2")

    let minecraftType: GameType
    let dockerClient: DockerClient

    init(for minecraftType: GameType, with dockerClient: DockerClient) {
        self.minecraftType = minecraftType
        self.dockerClient = dockerClient
    }
    
    func generateDockerFile(
        systemPackages: [String],
        installCommands: [String],
        volumes: [String] = []
    ) -> String {
        let systemPackages = systemPackages.joined(separator: " ")
        let volumes = volumes.map({ "\"\(MinecraftRuntimeDefaults.homeDirectory)/\($0)\"" })
            .joined(separator: ", ")
        let startupScriptPath = "\(MinecraftRuntimeDefaults.homeDirectory)/\(MinecraftRuntimeDefaults.startupScriptName)"
        
        return """
        FROM \(Self.baseImageTag.description) AS base
        
        # Install the runtime (java) and other dependencies
        RUN apk update \
            && apk add bash \(systemPackages) \
            && mkdir \(MinecraftRuntimeDefaults.homeDirectory)
        
        # Install Minecraft
        \(installCommands.joined(separator: "\n"))
        
        # Copy the server startup script
        COPY --chmod=755 \(MinecraftRuntimeDefaults.startupScriptName) \(startupScriptPath)

        # Container settings
        WORKDIR \(MinecraftRuntimeDefaults.homeDirectory)
        EXPOSE \(MinecraftRuntimeDefaults.serverPort)/tcp
        EXPOSE \(MinecraftRuntimeDefaults.serverPort)/udp
        VOLUME [ \(volumes) ]
        ENTRYPOINT [ "\(startupScriptPath)" ]
        """
    }
    
    func generateStartupScript(
        serverProperties: [String] = MinecraftRuntimeDefaults.serverProperties,
        command: String
    ) -> String {
        let properties = serverProperties.map {
            let envKey = $0.uppercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: ".", with: "_")
            return "PROPERTIES[\(envKey)]='\($0)'"
        }
        
        return """
        #!/bin/bash
        # Entry point for starting the minecraft server
        
        # Print out the java version
        java -version
        
        cd \(MinecraftRuntimeDefaults.homeDirectory)
        
        # Set EULA
        echo "eula=$EULA" > eula.txt
        
        # Collect environment variables (key = env var, value = minecraft name)
        declare -A PROPERTIES
        \(properties.joined(separator: "\n"))
        
        # Wipe the server.properties file and re-write it with any overrides found in environment variables
        echo '' > server.properties
        for key in "${!PROPERTIES[@]}"; do
            # Check if environment variable is set
            if [[ -n "${!key}" ]]; then
                echo "${PROPERTIES[$key]}=${!key}" >> server.properties
            fi
        done
        
        # Persistent server configuration files (i.e.: whitelist, ops, etc...)
        LEGACY_CONFIG_FILES=(
            "white-list.txt" "ops.txt" "banned-players.txt"
        )
        CONFIG_FILES=(
            "whitelist.json" "ops.json" "banned-players.json"
        )
        # Create the persistent server configuration file (if they don't exist already)
        for file_name in "${LEGACY_CONFIG_FILES[@]}"; do
            touch "\(MinecraftRuntimeDefaults.configurationsDirectory)/$file_name"
            # Create symlinks to the server persistent configurations
            ln -sf "\(MinecraftRuntimeDefaults.configurationsDirectory)/$file_name" "\(MinecraftRuntimeDefaults.homeDirectory)/$file_name"
        done
        # Create the persistent server configuration file (if they don't exist already)
        for file_name in "${CONFIG_FILES[@]}"; do
            if [[ ! -e "\(MinecraftRuntimeDefaults.configurationsDirectory)/$file_name" ]]; then
                echo "[]" > "\(MinecraftRuntimeDefaults.configurationsDirectory)/$file_name"
            fi
            # Create symlinks to the server persistent configurations
            ln -sf "\(MinecraftRuntimeDefaults.configurationsDirectory)/$file_name" "\(MinecraftRuntimeDefaults.homeDirectory)/$file_name"
        done
        
        # Extra JVM args users can specify
        touch "\(MinecraftRuntimeDefaults.configurationsDirectory)/jvm_args.txt"
        ln -sf "\(MinecraftRuntimeDefaults.configurationsDirectory)/jvm_args.txt" "\(MinecraftRuntimeDefaults.homeDirectory)/user_jvm_args.txt"
        
        # Add a guide to what these configuration files are for
        echo -e '# Minecraft server configuration files\\n\\nText files (.txt) are for legacy versions (prior to 1.8), any new version of Minecraft will use the JSON format.\\nIf your server is running Minecraft 1.8 or newer, you can delete the old (txt) files.\n\nYou can add custom JVM arguments to the jvm_args.txt file to further customize the Java runtime for your server. Add `-XX:+PrintFlagsFinal` at the top of the jvm_args.txt file to print all JVM options at runtime before starting the Minecraft server.' > \(MinecraftRuntimeDefaults.configurationsDirectory)/README.txt
        
        # Display current server.properties
        echo -e '\\nServer properties:'
        cat server.properties
        
        # Start the server
        echo -e "Starting server...\\nCustom args: $@\n"
        \(command)
        """
    }
    
    func build(minecraftVersion: GameVersion, imageName: String, tagLatest: Bool) async throws -> Docker.Image {
        let buildPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("minecraft_build")
            .appendingPathComponent("\(minecraftType.rawValue)_\(minecraftVersion)")
        // clean the builds environment
        do {
            if FileManager.default.fileExists(atPath: buildPath.path) {
                try FileManager.default.removeItem(at: buildPath)
            }
            try FileManager.default.createDirectory(at: buildPath, withIntermediateDirectories: true)
        }
        catch {
            throw MinecraftDockerError.buildError("Failed to prepare build environment: \(error)")
        }
        defer {
            try? FileManager.default.removeItem(at: buildPath)
        }

        // create a runtime provider based on the minecraft type to build
        let session = URLSession(configuration: .default)
        let runtimeProvider: MinecraftRuntimeProvider
        switch minecraftType {
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
        
        // get the download URL for this minecraft version
        let runtime = try await runtimeProvider.runtime(
            for: minecraftVersion == .latest ? try await runtimeProvider.latestVersion : minecraftVersion
        )
        
        // get the recommended java version for this build
        let javaVersion: JavaVersion
        if let java = runtime.javaVersion {
            javaVersion = java
        }
        else {
            MinecraftDockerLog.warning("No recommended java version found for Minecraft \(minecraftVersion). Using the latest release: \(JavaVersion.latest)")
            javaVersion = .latest
        }
        
        // write Dockerfile and startup scripts to disk
        let dockerfile = generateDockerFile(
            systemPackages: [javaVersion.packageName],
            installCommands: runtime.installCommands,
            volumes: runtime.mappedVolumes
        )
        let startupScript = generateStartupScript(command: runtime.startCommand)
        do {
            try dockerfile.write(
                to: buildPath.appendingPathComponent("Dockerfile"),
                atomically: true,
                encoding: .utf8
            )
            try startupScript.write(
                to: buildPath.appendingPathComponent(MinecraftRuntimeDefaults.startupScriptName),
                atomically: true,
                encoding: .utf8
            )
        }
        catch {
            throw MinecraftDockerError.buildError("Failed to write generated build files to disk at \(buildPath.path)")
        }

        // we use BuildKit which requires the base image to exist locally before starting the build
        try await dockerClient.pullImage(with: Self.baseImageTag)

        // build the image
        let tag = Docker.Image.Tag(name: imageName, tag: runtime.name)
        let image = try await dockerClient.buildImage(
            at: buildPath,
            tag: tag,
            labels: .labels(for: runtime.version, type: runtime.type),
            useCache: false,
            useBuildKit: true
        )

        // also tag the latest image if necessary
        if tagLatest {
            // tag the image as latest and return the new object
            // it's the same image (digest), but it has multiple tags
            do {
                let newTag = Docker.Image.Tag(
                    name: tag.name,
                    tag: generateLatestTag(version: minecraftVersion, type: minecraftType)
                )
                return try await dockerClient.tag(image: image, newTag)
            }
            catch {
                MinecraftDockerLog.error("Failed to tag latest image from \(tag)")
                return image
            }
        }
        else {
            return image
        }
    }
}

fileprivate extension Docker.Labels {
    static func labels(for version: GameVersion, type: GameType) -> Self {
        var labels = Docker.Labels()
        labels.add(name: "minecraft.server.type", value: type.rawValue)
        labels.add(name: "minecraft.server.version", value: version.minecraft)
        if let modLoaderVersion = version.modLoader {
            labels.add(name: "minecraft.server.isModded", value: "true")
            labels.add(name: "minecraft.server.modLoader.version", value: modLoaderVersion)
        }
        return labels
    }
}

fileprivate func generateLatestTag(version: GameVersion, type: GameType) -> String {
    switch type {
    case .vanilla: type.latestTag
    default: "\(version.minecraft)-\(type.latestTag)"
    }
}
