//
//  JavaVersion.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

enum JavaVersion: UInt, CustomStringConvertible {
    case java7 = 7
    case java8 = 8
    case java11 = 11
    case java16 = 16
    case java17 = 17
    
    /// Name of the java runtime package to be installed
    var packageName: String {
        switch self {
        case .java7:
            return "openjdk7-jre"
        case .java8:
            return "openjdk8-jre"
        case .java11:
            return "openjdk11-jre-headless"
        case .java16:
            return "openjdk16-jre-headless"
        case .java17:
            return "openjdk17-jre-headless"
        }
    }
    
    var description: String { "Java \(rawValue)" }
    
    static var latest: Self = .java17
}
