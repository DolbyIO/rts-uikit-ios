//
//  SubscriptionManager.swift
//

import Foundation
import MillicastSDK
import os
import AVFAudio

protocol SubscriptionManagerDelegate: AnyObject {
    func onSubscribed()

    func onSubscribedError(_ reason: String)

    func onVideoTrack(_ track: MCVideoTrack, withMid mid: String)

    func onAudioTrack(_ track: MCAudioTrack, withMid mid: String)

    func onActive(_ streamId: String, tracks: [String], sourceId: String?)

    func onInactive(_ streamId: String, sourceId: String?)

    func onStopped()

    func onLayers(_ mid: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData])

    func onConnected()

    func onConnectionError(_ status: Int32, withReason reason: String)
    
    func onDisconnected()

    func onSignalingError(_ message: String)

    func onStatsReport(_ report: MCStatsReport)

    func onViewerCount(_ count: Int32)
}

protocol SubscriptionManagerProtocol: AnyObject {
    var delegate: SubscriptionManagerDelegate? { get set }

    func connect(streamName: String, accountID: String, configuration: SubscriptionConfiguration) async -> Bool
    func startSubscribe() async -> Bool
    func stopSubscribe() async -> Bool
    func addRemoteTrack(_ sourceBuilder: StreamSourceBuilder)
    func projectVideo(for source: StreamSource, withQuality quality: VideoQuality)
    func unprojectVideo(for source: StreamSource)
    func projectAudio(for source: StreamSource)
    func unprojectAudio(for source: StreamSource)
}

final class SubscriptionManager: SubscriptionManagerProtocol {
    
    private enum Defaults {
        static let productionSubscribeURL = "https://director.millicast.com/api/director/subscribe"
        static let developmentSubscribeURL = "https://director-dev.millicast.com/api/director/subscribe"
    }
    
    private static let logger = Logger.make(category: String(describing: SubscriptionManager.self))

    private var subscriber: MCSubscriber!

    weak var delegate: SubscriptionManagerDelegate?

    func connect(streamName: String, accountID: String, configuration: SubscriptionConfiguration) async -> Bool {
        guard let subscriber = makeSubscriber(with: configuration) else {
            Self.logger.error("💼 Failed to initialise subscriber")
            return false
        }

        Self.logger.debug("💼 Connect with streamName & accountID")

        subscriber.setListener(self)
        self.subscriber = subscriber

        guard streamName.count > 0, accountID.count > 0 else {
            Self.logger.error("💼 Invalid credentials passed to connect")
            return false
        }

        let task = Task { [weak self] () -> Bool in
            guard let self = self else {
                return false
            }

            guard !self.isSubscribed, !self.isConnected else {
                Self.logger.error("💼 Subscriber has already connected or subscribed")
                return false
            }

            let credentials = self.makeCredentials(streamName: streamName, accountID: accountID, useDevelopmentServer: configuration.useDevelopmentServer)

            self.subscriber.setCredentials(credentials)

            guard self.subscriber.connect() else {
                Self.logger.error("💼 Subscriber has failed to connect")
                return false
            }

            return true
        }

        return await task.value
    }

    func startSubscribe() async -> Bool {
        let task = Task { [weak self] () -> Bool in
            Self.logger.debug("💼 Start subscribe")

            guard let self = self else {
                return false
            }

            guard self.isConnected else {
                Self.logger.error("💼 Subscriber hasn't completed connect to start subscribe")
                return false
            }

            guard !self.isSubscribed else {
                Self.logger.error("💼 Subscriber has already subscribed")
                return false
            }

            guard self.subscriber.subscribe() else {
                Self.logger.error("💼 Subscribe call has failed")
                return false
            }
            
            return true
        }

        return await task.value
    }

    func stopSubscribe() async -> Bool {
        let task = Task { [weak self] () -> Bool in
            Self.logger.debug("💼 Stop subscribe")

            guard let self = self, let subscriber = subscriber else {
                return false
            }

            defer {
                self.subscriber.setListener(nil)
                self.subscriber = nil
            }
            
            let unsubscribeResult = subscriber.unsubscribe()
            if !unsubscribeResult {
                Self.logger.error("💼 Failed to unsubscribe")
            }
            
            let disconnectResult = subscriber.disconnect()
            if !disconnectResult {
                Self.logger.error("💼 Failed to disconnect")
            }
            
            return disconnectResult && unsubscribeResult
        }
        return await task.value
    }

    func addRemoteTrack(_ sourceBuilder: StreamSourceBuilder) {
        Self.logger.debug("💼 Add remote track for source - \(sourceBuilder.sourceId)")
        sourceBuilder.supportedTrackItems.forEach { subscriber.addRemoteTrack($0.mediaType.rawValue) }
    }

    func projectVideo(for source: StreamSource, withQuality quality: VideoQuality) {
        let videoTrack = source.videoTrack
        let matchingVideoQuality = source.lowLevelVideoQualityList.matching(videoQuality: quality)
        
        Self.logger.debug("💼 Project video for source \(source.sourceId) with quality - \(String(describing: matchingVideoQuality?.description))")

        let projectionData = MCProjectionData()
        projectionData.media = videoTrack.trackInfo.mediaType.rawValue
        projectionData.mid = videoTrack.trackInfo.mid
        projectionData.trackId = videoTrack.trackInfo.trackID
        projectionData.layer = matchingVideoQuality?.layerData

        subscriber.project(source.sourceId.value, withData: [projectionData])
    }

    func unprojectVideo(for source: StreamSource) {
        Self.logger.debug("💼 Unproject video for source \(source.sourceId)")
        let videoTrack = source.videoTrack
        subscriber.unproject([videoTrack.trackInfo.mid])
    }

    func projectAudio(for source: StreamSource) {
        Self.logger.debug("💼 Project audio for source \(source.sourceId)")
        guard let audioTrack = source.audioTracks.first else {
            return
        }

        let projectionData = MCProjectionData()
        audioTrack.track.enable(true)
        audioTrack.track.setVolume(1)
        projectionData.media = audioTrack.trackInfo.mediaType.rawValue
        projectionData.mid = audioTrack.trackInfo.mid
        projectionData.trackId = audioTrack.trackInfo.trackID

        subscriber.project(source.sourceId.value, withData: [projectionData])
    }

    func unprojectAudio(for source: StreamSource) {
        Self.logger.debug("💼 Unproject audio for source \(source.sourceId)")
        guard let audioTrack = source.audioTracks.first else {
            return
        }

        subscriber.unproject([audioTrack.trackInfo.mid])
    }
}

// MARK: Maker functions

private extension SubscriptionManager {

    func makeSubscriber(with configuration: SubscriptionConfiguration) -> MCSubscriber? {
        let subscriber = MCSubscriber.create()
                
        let options = MCClientOptions()
        options.autoReconnect = configuration.autoReconnect
        options.videoJitterMinimumDelayMs = Int32(configuration.videoJitterMinimumDelayInMs)
        options.statsDelayMs = Int32(configuration.statsDelayMs)
        if let rtcEventLogOutputPath = configuration.rtcEventLogPath {
            options.rtcEventLogOutputPath = rtcEventLogOutputPath
        }
        options.disableAudio = configuration.disableAudio
        options.forcePlayoutDelay = configuration.noPlayoutDelay

        subscriber?.setOptions(options)
        subscriber?.enableStats(configuration.enableStats)

        return subscriber
    }

    func makeCredentials(streamName: String, accountID: String, useDevelopmentServer: Bool) -> MCSubscriberCredentials {
        let credentials = MCSubscriberCredentials()
        credentials.accountId = accountID
        credentials.streamName = streamName
        credentials.token = ""
        credentials.apiUrl = useDevelopmentServer ? Defaults.developmentSubscribeURL : Defaults.productionSubscribeURL

        return credentials
    }
}

// MARK: MCSubscriberListener implementation

extension SubscriptionManager: MCSubscriberListener {
    func onDisconnected() {
        Self.logger.debug("💼 Delegate - onDisconnected")
        delegate?.onDisconnected()
    }

    func onSubscribed() {
        Self.logger.debug("💼 Delegate - onSubscribed")
        delegate?.onSubscribed()
    }

    func onSubscribedError(_ reason: String) {
        Self.logger.error("💼 Delegate - onSubscribedError \(reason)")
        delegate?.onSubscribedError(reason)
    }

    func onVideoTrack(_ track: MCVideoTrack, withMid mid: String) {
        Self.logger.debug("💼 Delegate - onVideoTrack with mid \(mid)")
        delegate?.onVideoTrack(track, withMid: mid)
    }

    func onAudioTrack(_ track: MCAudioTrack, withMid mid: String) {
        Self.logger.debug("💼 Delegate - onAudioTrack with mid \(mid)")
        delegate?.onAudioTrack(track, withMid: mid)
    }

    func onActive(_ streamId: String, tracks: [String], sourceId: String) {
        Self.logger.debug("💼 Delegate - onActive with sourceId \(sourceId), tracks - \(tracks)")
        delegate?.onActive(streamId, tracks: tracks, sourceId: sourceId)
    }

    func onInactive(_ streamId: String, sourceId: String) {
        Self.logger.debug("💼 Delegate - onInactive with sourceId \(sourceId)")
        delegate?.onInactive(streamId, sourceId: sourceId)
    }

    func onStopped() {
        Self.logger.debug("💼 Delegate - onStopped")
        delegate?.onStopped()
    }

    func onVad(_ mid: String, sourceId: String) {
        Self.logger.debug("💼 Delegate - onVad with mid \(mid), sourceId \(sourceId)")
    }

    func onLayers(_ mid: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData]) {
        Self.logger.debug("💼 Delegate - onLayers for mid - \(mid) with activeLayers \(activeLayers), inactiveLayers \(inactiveLayers)")
        delegate?.onLayers(mid, activeLayers: activeLayers, inactiveLayers: inactiveLayers)
    }

    func onConnected() {
        Self.logger.debug("💼 Delegate - onConnected")
        delegate?.onConnected()
    }

    func onConnectionError(_ status: Int32, withReason reason: String) {
        Self.logger.error("💼 Delegate - onConnectionError")
        delegate?.onConnectionError(status, withReason: reason)
    }

    func onSignalingError(_ message: String) {
        Self.logger.error("💼 Delegate - onSignalingError")
        delegate?.onSignalingError(message)
    }

    func onStatsReport(_ report: MCStatsReport) {
        Self.logger.debug("💼 Delegate - onStatsReport")
        delegate?.onStatsReport(report)
    }

    func onViewerCount(_ count: Int32) {
        Self.logger.debug("💼 Delegate - onViewerCount")
        delegate?.onViewerCount(count)
    }
}

// MARK: Helper functions

private extension SubscriptionManager {
    var isSubscribed: Bool {
        subscriber.isSubscribed()
    }

    var isConnected: Bool {
        subscriber.isConnected()
    }
}
