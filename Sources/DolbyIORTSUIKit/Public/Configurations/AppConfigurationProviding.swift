//
//  AppConfigurationProviding.swift
//

import Combine
import Foundation

public protocol AppConfigurationProviding: AnyObject {
    var showDebugFeatures: Bool { get }
}
