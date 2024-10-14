//
//  JavaVersion.swift
//  
//
//  Created by Ricky Dall'Armellina on 8/10/23.
//

import Foundation

struct JavaVersion: RawRepresentable, CustomStringConvertible, Equatable {
    let rawValue: UInt
    
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    var description: String { "Java \(rawValue)" }
    
    // Known java versions
    static let java7 = JavaVersion(rawValue: 7)
    static let java8 = JavaVersion(rawValue: 8)
    static let java11 = JavaVersion(rawValue: 11)
    static let java16 = JavaVersion(rawValue: 16)
    static let java17 = JavaVersion(rawValue: 17)
    static let java21 = JavaVersion(rawValue: 21)
    static let java22 = JavaVersion(rawValue: 22)
    static let java23 = JavaVersion(rawValue: 23)
    static let java24 = JavaVersion(rawValue: 24)
    
    static var latest: Self = .java21
    
    /// Name of the java runtime package to be installed
    var packageName: String {
        switch self {
        case .java7, .java8:
            // old java package name style
            return "openjdk\(rawValue)-jre"
        default:
            // assume new standard java package name style
            return "openjdk\(rawValue)-jre-headless"
        }
    }
}
