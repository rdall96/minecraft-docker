//
//  Version.swift
//
//
//  Created by Ricky Dall'Armellina on 8/24/23.
//

import Foundation

enum Version: String {
    
    /// initial version
    case v2_0_0 = "2.0.0"
    
    /**
     - Tag latest for versions other than vanilla and in bulk builds.
     - Run command to start new containers from the built images.
     - Removed list command in favor of `--list` argument in the download command.
     - Fix for hanging `forge` builds.
     */
    case v2_1_0 = "2.1.0"
    
    /**
     - Images won't be pushed to the remote if they have the same ID (cached builds).
     - Run command now supports cleaning cleaning the container artifacts after it is stopped.
     - Reduced the timeout for cached builds (forge workaround implemented in version 2.1.0) to 2 minutes to speed up bulk builds.
     */
    case v2_1_1 = "2.1.1"
    
    /**
     - Java versions are determined automatically. New support will be smoother this way.
     - Updated docker dependency.
     */
    case v2_2_0 = "2.2.0"
    
    /**
     - Added support for NeoForged mod loader.
     - Added support for Quilt mod loader (beta).
     */
    case v2_3_0 = "2.3.0"
    
    /**
     - Ability to specify the mod loader version when building modded images.
     - Added `max-tick-time` and `max-world-size` to the server properties.
     - Added support for builds requiring java 22, 23, and 24.
     */
    case v2_4_0 = "2.4.0"
    
    /**
     - Users can specify custom JVM arguments in the jvm_args.txt file.
     - Users can specify custom Minecraft server arguments to attach to the startup script.
     - Fixed bug with tagging the latest docker image when building specific mod loader versions.
     */
    case v2_5_0 = "2.5.0"

    /**
     - Updated the underlying library used to run Docker actions: the new versions is more robust and fixes a long standing issue with some Minecraft builds hanging.
     - Updated Swift toolchain: 5.8 -> 5.10
     - Cleaned up logic to push images to DockerHub after building.
     - Throw an error from the build command if all images fail to build.
     - Option to specify which Docker connection to use: local socket, or server.
     */
    case v2_6_1 = "2.6.1"
}

extension Version {
    static let current: Self = .v2_6_1
}

extension Version: CustomStringConvertible {
    var description: String { rawValue }
}
