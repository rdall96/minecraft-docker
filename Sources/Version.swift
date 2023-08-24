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
}

extension Version {
    static var current: Self = .v2_1_0
}

extension Version: CustomStringConvertible {
    var description: String { rawValue }
}
