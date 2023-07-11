//
//  MillicastLoggerHandler.swift
//

import Foundation
import MillicastSDK
import os

final class MillicastLoggerHandler: NSObject {
    
    private static let logger = Logger.make(category: String(describing: MillicastLoggerHandler.self))
    
    override init() {
        super.init()
        MCLogger.setDelegate(self)
    }
}

extension MillicastLoggerHandler: MCLoggerDelegate {
    func onLog(withMessage message: String!, level: MCLogLevel) {
        Self.logger.log("🪵 onLog - \(message, privacy: .public), log-level - \(level.rawValue, privacy: .public)")
    }
}
