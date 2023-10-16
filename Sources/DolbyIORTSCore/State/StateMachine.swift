//
//  StateMachine.swift
//

import Combine
import Foundation
import MillicastSDK
import os

final class StateMachine {
    private static let logger = Logger.make(category: String(describing: StateMachine.self))

    private(set) var currentState: State {
        didSet {
            stateSubject.send(currentState)
            Self.logger.debug("🎰 State change from \(oldValue.description) to \(self.currentState.description)")
        }
    }

    private let stateSubject: PassthroughSubject<State, Never> = PassthroughSubject()
    lazy var statePublisher: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()
    private(set) var cachedSourceZeroVideoTrackAndMid: VideoTrackAndMid?
    private(set) var cachedSourceZeroAudioTrackAndMid: AudioTrackAndMid?

    init(initialState: State) {
        currentState = initialState
    }

    func startConnection(streamName: String, accountID: String) {
        currentState = .connecting
    }

    func startSubscribe() {
        currentState = .subscribing
    }

    func stopSubscribe() {
        currentState = .disconnected
    }

    func setPlayingAudio(_ enable: Bool, for source: StreamSource) {
        switch currentState {
        case let .subscribed(state):
            state.setPlayingAudio(enable, for: source.sourceId.value)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on setPlayingAudio - \(self.currentState.description)")
        }
    }

    func setPlayingVideo(_ enable: Bool, for source: StreamSource) {
        switch currentState {
        case let .subscribed(state):
            state.setPlayingVideo(enable, for: source.sourceId.value)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on setPlayingVideo - \(self.currentState.description)")
        }
    }

    func onConnected() {
        currentState = .connected
    }

    func onConnectionError(_ status: Int32, withReason reason: String) {
        currentState = .error(.init(error: .connectFailed(reason: reason)))
    }
    
    func onDisconnected() {
        currentState = .disconnected
    }

    func onSubscribed() {
        currentState = .subscribed(
            .init(
                cachedVideoTrackDetail: cachedSourceZeroVideoTrackAndMid,
                cachedAudioTrackDetail: cachedSourceZeroAudioTrackAndMid
            )
        )
        cachedSourceZeroAudioTrackAndMid = nil
        cachedSourceZeroAudioTrackAndMid = nil

    }

    func onSubscribedError(_ reason: String) {
        currentState = .error(.init(error: .subscribeFailed(reason: reason)))
    }

    func onSignalingError(_ message: String) {
        currentState = .error(.init(error: .signalingError(reason: message)))
    }

    func onActive(_ streamId: String, tracks: [String], sourceId: String?) {
        switch currentState {
        case var .subscribed(state):
            state.add(streamId: streamId, sourceId: sourceId, tracks: tracks)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on onActive - \(self.currentState.description)")
        }
    }

    func onInactive(_ streamId: String, sourceId: String?) {
        switch currentState {
        case var .subscribed(state):
            state.remove(streamId: streamId, sourceId: sourceId)
            
            // FIXME: Currently SDK does not have a callback for Publisher stopping the publishing
            // What we get instead is `onInactive` callbacks for all the video sources - ie, `onInactive` is called `n` times if we have `n` sources
            // This workaround checks for active `source` count to decide the expected `state` transition
            if state.sources.isEmpty {
                currentState = .stopped
            } else {
                currentState = .subscribed(state)
            }
        default:
            Self.logger.error("🛑 Unexpected state on onInactive - \(self.currentState.description)")
        }
    }

    func onVideoTrack(_ track: MCVideoTrack, withMid mid: String) {
        switch currentState {
        case let .subscribed(state):
            state.addVideoTrack(track, mid: mid)
            currentState = .subscribed(state)

        default:
            self.cachedSourceZeroVideoTrackAndMid = VideoTrackAndMid(videoTrack: track, mid: mid)
            Self.logger.error("🛑 Unexpected state on onVideoTrack - \(self.currentState.description)")
        }
    }

    func onAudioTrack(_ track: MCAudioTrack, withMid mid: String) {
        switch currentState {
        case let .subscribed(state):
            state.addAudioTrack(track, mid: mid)
            currentState = .subscribed(state)
        default:
            self.cachedSourceZeroAudioTrackAndMid = AudioTrackAndMid(audioTrack: track, mid: mid)
            Self.logger.error("🛑 Unexpected state on onAudioTrack - \(self.currentState.description)")
        }
    }

    func onLayers(_ mid: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData]) {
        switch currentState {
        case let .subscribed(state):
            let streamTypes: [StreamSource.LowLevelVideoQuality]
            let filteredActiveLayers = activeLayers.filter({ layer in
                // For H.264 there are no temporal layers and the id is set to 255. For VP8 use the first temporal layer.
                return layer.temporalLayerId == 0 || layer.temporalLayerId == 255
            })

            switch filteredActiveLayers.count {
            case 2:
                streamTypes = [
                    .auto,
                    .high(layer: filteredActiveLayers[0]),
                    .low(layer: filteredActiveLayers[1])
                ]
            case 3:
                streamTypes = [
                    .auto,
                    .high(layer: filteredActiveLayers[0]),
                    .medium(layer: filteredActiveLayers[1]),
                    .low(layer: filteredActiveLayers[2])
                ]
            default:
                streamTypes = [.auto]
            }

            state.setAvailableStreamTypes(streamTypes, for: mid)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on onLayers - \(self.currentState.description)")
        }
    }
    
    func selectVideoQuality(_ quality: VideoQuality, for source: StreamSource) {
        switch currentState {
        case let .subscribed(state):
            state.setSelectedVideoQuality(quality, for: source.sourceId.value)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on selectVideoQuality - \(self.currentState.description)")
        }
    }

    func onStatsReport(_ streamingStats: AllStreamStatistics) {
        switch currentState {
        case var .subscribed(state):
            state.updateStreamingStatistics(streamingStats)
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on onStatsReport - \(self.currentState.description)")
        }
    }

    func updateNumberOfStreamViewers(_ count: Int32) {
        switch currentState {
        case var .subscribed(state):
            state.updateViewerCount(Int(count))
            currentState = .subscribed(state)
        default:
            Self.logger.error("🛑 Unexpected state on onViewerCount - \(self.currentState.description)")
        }
    }

    func onStopped() {
        currentState = .stopped
    }
}
