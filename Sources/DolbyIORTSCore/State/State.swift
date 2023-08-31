//
//  State.swift
//

import Foundation
import MillicastSDK

enum State: CustomStringConvertible {
    case disconnected
    case connecting
    case connected
    case subscribing
    case subscribed(SubscribedState)
    case stopped
    case error(ErrorState)

    var description: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .subscribing:
            return "subscribing"
        case .subscribed:
            return "subscribed"
        case .stopped:
            return "stopped"
        case let .error(state):
            return "error \(state.error.localizedDescription)"
        }
    }
}

struct VideoTrackAndMid {
    let videoTrack: MCVideoTrack
    let mid: String
}

struct AudioTrackAndMid {
    let audioTrack: MCAudioTrack
    let mid: String
}

struct SubscribedState {

    private(set) var streamSourceBuilders: [StreamSourceBuilder]
    private(set) var numberOfStreamViewers: Int
    private(set) var streamingStats: StreamingStatistics?
    private(set) var cachedSourceZeroVideoTrackAndMid: VideoTrackAndMid?
    private(set) var cachedSourceZeroAudioTrackAndMid: AudioTrackAndMid?

    init(cachedVideoTrackDetail: VideoTrackAndMid?, cachedAudioTrackDetail: AudioTrackAndMid?) {
        cachedSourceZeroVideoTrackAndMid = cachedVideoTrackDetail
        cachedSourceZeroAudioTrackAndMid = cachedAudioTrackDetail
        streamSourceBuilders = []
        numberOfStreamViewers = 0
    }

    mutating func add(streamId: String, sourceId: String?, tracks: [String]) {
        let streamSourceBuilder = StreamSourceBuilder.init(streamId: streamId, sourceId: sourceId, tracks: tracks)
        if let videoTrackAndMid = cachedSourceZeroVideoTrackAndMid {
            streamSourceBuilder.addVideoTrack(videoTrackAndMid.videoTrack, mid: videoTrackAndMid.mid)
            cachedSourceZeroVideoTrackAndMid = nil
        }
        if let audioTrackAndMid = cachedSourceZeroAudioTrackAndMid {
            streamSourceBuilder.addAudioTrack(audioTrackAndMid.audioTrack, mid: audioTrackAndMid.mid)
            cachedSourceZeroAudioTrackAndMid = nil
        }
        streamSourceBuilders.append(streamSourceBuilder)
    }

    mutating func remove(streamId: String, sourceId: String?) {
        streamSourceBuilders.removeAll { $0.streamId == streamId && $0.sourceId.value == sourceId }
    }

    func addAudioTrack(_ track: MCAudioTrack, mid: String) {
        guard let builder = streamSourceBuilders.first(where: { $0.hasMissingAudioTrack}) else {
            return
        }
        builder.addAudioTrack(track, mid: mid)
    }

    func addVideoTrack(_ track: MCVideoTrack, mid: String) {
        guard let builder = streamSourceBuilders.first(where: { $0.hasMissingVideoTrack }) else {
            return
        }
        builder.addVideoTrack(track, mid: mid)
    }

    mutating func removeBuilder(with sourceId: String?) {
        guard let indexToRemove = streamSourceBuilders.firstIndex(where: { $0.sourceId.value == sourceId }) else {
            return
        }

        streamSourceBuilders.remove(at: indexToRemove)
    }

    func setPlayingAudio(_ enable: Bool, for sourceId: String?) {
        guard let builder = streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
            return
        }
        builder.setPlayingAudio(enable)
    }

    func setPlayingVideo(_ enable: Bool, for sourceId: String?) {
        guard let builder = streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
            return
        }
        builder.setPlayingVideo(enable)
    }

    func setAvailableStreamTypes(_ list: [StreamSource.LowLevelVideoQuality], for mid: String) {
        guard let builder = streamSourceBuilders.first(where: { $0.videoTrack?.trackInfo.mid == mid }) else {
            return
        }

        builder.setAvailableVideoQualityList(list)
    }
    
    func setSelectedVideoQuality(_ videoQuality: VideoQuality, for sourceId: String?) {
        guard let builder = streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
            return
        }
        builder.setSelectedVideoQuality(videoQuality)
    }

    mutating func updateViewerCount(_ count: Int) {
        numberOfStreamViewers = count
    }

    mutating func updateStreamingStatistics(_ stats: [StreamingStatistics]) {
        streamSourceBuilders.forEach { builder in
            if let mid = builder.videoTrack?.trackInfo.mid {
                stats.first { currentStat in
                    currentStat.mid == mid
                }.map {
                    builder.setStatistics($0)
                }
            }
        }
    }

    var sources: [StreamSource] {
        streamSourceBuilders.compactMap {
            do {
                return try $0.build()
            } catch {
                return nil
            }
        }
    }
}

struct ErrorState: Equatable {
    let error: StreamError
}
