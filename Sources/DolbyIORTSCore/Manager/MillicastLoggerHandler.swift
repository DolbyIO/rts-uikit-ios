//
//  MillicastLoggerHandler.swift
//

import Foundation
import MillicastSDK
import os

final class MillicastLoggerHandler: NSObject {
    
    private static let logger = Logger.make(category: String(describing: MillicastLoggerHandler.self))
    
    private var logFilePath: String?

    override init() {
        super.init()
        MCLogger.setDelegate(self)
        MCLogger.disableWebsocketLogs(true)
    }
    
    func updateLogFileDetail(
        documentDirectoryPath: String?,
        subscribeTimeStamp: String
    ) {
        guard let documentsDirectoryPath = documentDirectoryPath else {
            return
        }
        
        self.logFilePath = "\(documentsDirectoryPath)/\(subscribeTimeStamp)_sdklogs.txt"
    }
}

extension MillicastLoggerHandler: MCLoggerDelegate {
    func onLog(withMessage message: String!, level: MCLogLevel) {
        Self.logger.log("🪵 onLog - \(message, privacy: .public), log-level - \(level.rawValue, privacy: .public)")
        
        guard
            let logFilePath = logFilePath,
            let messageData = "\(String(describing: message)) \n\n".data(using: .utf8)
        else {
            Self.logger.error("🪵 Error writing file - no file path provided")
            return
        }
        
        let fileURL = URL(fileURLWithPath: logFilePath)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(messageData)
                fileHandle.closeFile()
            } else {
                try messageData.write(to: fileURL, options: .atomicWrite)
            }
        } catch {
            Self.logger.error("🪵 Error writing file - \(error.localizedDescription, privacy: .public)")
        }
    }
}
