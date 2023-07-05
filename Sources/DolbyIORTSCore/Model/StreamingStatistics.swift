//
//  StreamingStatistics.swift
//

import Foundation
import MillicastSDK

public struct StreamingStatistics: Equatable, Hashable {
    public let mid: String?
    public let roundTripTime: Double?
    public let statsInboundRtp: StatsInboundRtp?
    
    public struct StatsInboundRtp: Equatable, Hashable {
        public let kind: String
        public let sid: String
        public let decoderImplementation: String?
        public let trackIdentifier: String
        public let decoder: String?
        public let processingDelay: Double
        public let decodeTime: Double
        public let frameWidth: Int
        public let frameHeight: Int
        public let fps: Int
        public let audioLevel: Int
        public let totalEnergy: Double
        public let framesReceived: Int
        public let framesDecoded: Int
        public let framesDropped: Int
        public let jitterBufferEmittedCount: Int
        public let jitterBufferDelay: Double
        public let jitterBufferTargetDelay: Double
        public let jitterBufferMinimumtDelay: Double
        public let nackCount: Int
        public let bytesReceived: Int
        public let totalSampleDuration: Double
        public let codec: String?
        public let jitter: Double
        public let packetsReceived: Double
        public let packetsLost: Double
        public let timestamp: Double
        public var codecName: String?
        
        public var videoResolution: String {
            "\(frameWidth) x \(frameHeight)"
        }
    }
}

extension StreamingStatistics {
    public static func build(report: MCStatsReport) -> [StreamingStatistics] {
        let inboundRtpStreamStatsType = MCInboundRtpStreamStats.get_type()
        guard let inboundRtpStreamStatsList = report.getStatsOf(inboundRtpStreamStatsType) as? [MCInboundRtpStreamStats] else {
            return []
        }
        
        let receivedType = MCRemoteInboundRtpStreamStats.get_type()
        let remoteInboundStreamStatsList = report.getStatsOf(receivedType) as? [MCRemoteInboundRtpStreamStats]
        
        let roundTripTime = remoteInboundStreamStatsList?.first.map { $0.round_trip_time }
        
        let codecType = MCCodecsStats.get_type()
        let codecStatsList = report.getStatsOf(codecType) as? [MCCodecsStats]
        
        return inboundRtpStreamStatsList.map {streamStats in
            return StreamingStatistics(streamStats, roundTripTime: roundTripTime, codecStatsList: codecStatsList)
        }
    }
}

extension StreamingStatistics {
    init(_ inboundRtpStreamStats: MCInboundRtpStreamStats, roundTripTime : Double?, codecStatsList: [MCCodecsStats]?) {
        self.mid = inboundRtpStreamStats.mid as String
        self.roundTripTime = roundTripTime
        self.statsInboundRtp = StatsInboundRtp(inboundRtpStreamStats, codecStatsList: codecStatsList)
    }
}

extension StreamingStatistics.StatsInboundRtp {
    init(_ stats: MCInboundRtpStreamStats, codecStatsList: [MCCodecsStats]?) {
        kind = stats.kind as String
        sid = stats.sid  as String
        decoderImplementation = stats.decoder_implementation as String?
        processingDelay =  msNormalised(numerator: stats.total_processing_delay, denominator: Double(stats.frames_decoded))
        decodeTime = msNormalised(numerator: stats.total_decode_time, denominator: Double(stats.frames_decoded))
        frameWidth = Int(stats.frame_width)
        frameHeight = Int(stats.frame_height)
        fps = Int(stats.frames_per_second)
        bytesReceived = Int(stats.bytes_received)
        framesReceived = Int(stats.frames_received)
        packetsReceived = Double(stats.packets_received)
        framesDecoded = Int(stats.frames_decoded)
        framesDropped = Int(stats.frames_dropped)
        jitterBufferEmittedCount = Int(stats.jitter_buffer_emitted_count)
        jitter = stats.jitter * 1000
        jitterBufferDelay = msNormalised(numerator: stats.jitter_buffer_delay, denominator: Double(stats.jitter_buffer_emitted_count))
        jitterBufferTargetDelay = msNormalised(numerator: stats.jitter_buffer_delay, denominator: Double(stats.jitter_buffer_emitted_count))
        jitterBufferMinimumtDelay = msNormalised(numerator: stats.jitter_buffer_minimum_delay, denominator: Double(stats.jitter_buffer_emitted_count))
        nackCount = Int(stats.nack_count)
        packetsLost = Double(stats.packets_lost)
        
        trackIdentifier = stats.track_identifier as String
        decoder = stats.decoder_implementation as String?
        audioLevel = Int(stats.audio_level)
        totalEnergy = stats.total_audio_energy
        totalSampleDuration = stats.total_samples_duration
        codec = stats.codec_id as String?
        timestamp = Double(stats.timestamp)
        
        if let codecStats = codecStatsList?.first(where: { $0.sid == stats.codec_id }) {
            codecName = codecStats.mime_type as String
        } else {
            codecName = nil
        }
    }
}

func msNormalised(numerator: Double, denominator: Double) -> Double {
    denominator == 0 ? 0 : numerator * 1000 / denominator
}
