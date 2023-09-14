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
        MCLogger.disableWebsocketLogs(true)
    }
}

extension MillicastLoggerHandler: MCLoggerDelegate {
    func onLog(withMessage message: String!, level: MCLogLevel) {
        Self.logger.debug("🪵 onLog - \(message), log-level - \(level.rawValue)")
    }
}
