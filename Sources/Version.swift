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
     */
    case v2_3_0 = "2.3.0"
}

extension Version {
    static var current: Self = .v2_3_0
}

extension Version: CustomStringConvertible {
    var description: String { rawValue }
}
