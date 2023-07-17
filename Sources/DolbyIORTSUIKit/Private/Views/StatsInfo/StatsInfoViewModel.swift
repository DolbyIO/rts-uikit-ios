//
//  StatsInfoViewModel.swift
//

import Combine
import DolbyIORTSCore
import Foundation
import SwiftUI

final class StatsInfoViewModel: ObservableObject {
    private let streamSource: StreamSource

    init(streamSource: StreamSource) {
        self.streamSource = streamSource
    }
    
    struct StatData: Identifiable {
        var id = UUID()
        var key: LocalizedStringKey
        var value: String
    }

    var data: [StatData] {
        guard let stats = streamSource.statisticsData else {
            return []
        }

        var result = [StatData]()

        if let rtt = stats.roundTripTime {
            result.append(StatData(key: "stream.stats.rtt.label", value: String(rtt)))
        }
        if let videoResolution = stats.videoStatsInboundRtp?.videoResolution {
            result.append(StatData(key: "stream.stats.video-resolution.label", value: videoResolution))
        }
        if let fps = stats.videoStatsInboundRtp?.fps {
            result.append(StatData(key: "stream.stats.fps.label", value: String(fps)))
        }
        if let audioBytesReceived = stats.audioStatsInboundRtp?.bytesReceived {
            result.append(StatData(key: "stream.stats.audio-total-received.label", value: formatBytes(bytes: audioBytesReceived)))
        }
        if let videoBytesReceived = stats.videoStatsInboundRtp?.bytesReceived {
            result.append(StatData(key: "stream.stats.video-total-received.label", value: formatBytes(bytes: videoBytesReceived)))
        }
        if let audioPacketsLost = stats.audioStatsInboundRtp?.packetsLost {
            result.append(StatData(key: "stream.stats.audio-packet-loss.label", value: String(audioPacketsLost)))
        }
        if let videoPacketsLost = stats.videoStatsInboundRtp?.packetsLost {
            result.append(StatData(key: "stream.stats.video-packet-loss.label", value: String(videoPacketsLost)))
        }
        if let audioJitter = stats.audioStatsInboundRtp?.jitter {
            result.append(StatData(key: "stream.stats.audio-jitter.label", value: "\(audioJitter)"))
        }
        if let videoJitter = stats.videoStatsInboundRtp?.jitter {
            result.append(StatData(key: "stream.stats.video-jitter.label", value: "\(videoJitter)"))
        }
        if let timestamp = stats.audioStatsInboundRtp?.timestamp {
            result.append(StatData(key: "stream.stats.timestamp.label", value: String(timestamp))) // change to dateStr when timestamp is fixed
        }
        let audioCodec = stats.audioStatsInboundRtp?.codecName
        let videoCodec = stats.videoStatsInboundRtp?.codecName
        if audioCodec != nil || videoCodec != nil {
            var delimiter = ", "
            if audioCodec == nil || videoCodec == nil {
                delimiter = ""
            }
            let codecs = "\(audioCodec ?? "")\(delimiter)\(videoCodec ?? "")"
            result.append(StatData(key: "stream.stats.codecs.label", value: codecs))
        }
        return result
    }

    private func dateStr(timestamp: Double) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return dateFormatter.string(from: date)
    }

    private func formatBytes(bytes: Int) -> String {
        return "\(formatNumber(input: bytes))B"
    }

    private func formatBitRate(bitRate: Int) -> String {
        let value = formatNumber(input: bitRate).lowercased()
        return "\(value)bps"
    }

    private func formatNumber(input: Int) -> String {
        if input < KILOBYTES { return String(input) }
        if input >= KILOBYTES && input < MEGABYTES { return "\(input / KILOBYTES) K"} else { return "\(input / MEGABYTES) M" }
    }
}

private let KILOBYTES = 1024
private let MEGABYTES = KILOBYTES * KILOBYTES
