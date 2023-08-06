//
//  Utils.swift
//

import AVFAudio
import Foundation

/**
 * Utility methods used in the SA.
 */
class Utils {
    public static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
#if os(iOS)
            // For subscriber, we only need playback. Not recording is required.
            try session.setCategory(.playback, mode: .videoChat, options: [.mixWithOthers])
#else
            try session.setCategory(.playback, options: [.mixWithOthers])
#endif
            try session.setActive(true)
        } catch {
            print("Failed audio session: \(error)")
            return
        }
    }
    
    public static func getCurrentTimestampInMilliseconds() -> Int64 {
        let currentTime = Date().timeIntervalSince1970
        return Int64(currentTime * 1000)
    }
    
    public static func getISO8601TimestampForCurrentDate() -> String {
        let currentDate = Date.now
        let utcISODateFormatter = ISO8601DateFormatter()
        utcISODateFormatter.formatOptions = [.withFullDate, .withFullTime]
        return utcISODateFormatter.string(from: currentDate)
    }
}
