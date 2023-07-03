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

    func onSignalingError(_ message: String)

    func onStatsReport(_ report: MCStatsReport)

    func onViewerCount(_ count: Int32)
}

protocol SubscriptionManagerProtocol: AnyObject {
    var delegate: SubscriptionManagerDelegate? { get set }

    func connect(streamName: String, accountID: String) async -> Bool
    func startSubscribe() async -> Bool
    func stopSubscribe() async -> Bool
    func selectVideoQuality(_ quality: StreamSource.VideoQuality, for source: StreamSource)
    func addRemoteTrack(_ sourceBuilder: StreamSourceBuilder)
    func projectVideo(for source: StreamSource, withQuality quality: StreamSource.VideoQuality)
    func unprojectVideo(for source: StreamSource)
    func projectAudio(for source: StreamSource)
    func unprojectAudio(for source: StreamSource)
}

final class SubscriptionManager: SubscriptionManagerProtocol {
    private enum Defaults {
        static let subscribeURL = "https://director.millicast.com/api/director/subscribe"
    }
    private static let logger = Logger.make(category: String(describing: SubscriptionManager.self))

    private var subscriber: MCSubscriber!

    weak var delegate: SubscriptionManagerDelegate?

    func connect(streamName: String, accountID: String) async -> Bool {
        if subscriber != nil {
            _ = await stopSubscribe()
        }
        
        let subscriber = makeSubscriber()
        subscriber.setListener(self)

        Self.logger.debug("💼 Connect with streamName & accountID")

        self.subscriber = subscriber

        guard streamName.count > 0, accountID.count > 0 else {
            Self.logger.warning("💼 Invalid credentials passed to connect")
            return false
        }

        let task = Task { [weak self] () -> Bool in
            guard let self = self else {
                return false
            }

            guard !self.isSubscribed, !self.isConnected else {
                Self.logger.warning("💼 Subscriber has already connected or subscribed")
                return false
            }

            let credentials = self.makeCredentials(streamName: streamName, accountID: accountID)

            self.subscriber.setCredentials(credentials)

            guard self.subscriber.connect() else {
                Self.logger.warning("💼 Subscriber has failed to connect")
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
                Self.logger.warning("💼 Subscriber hasn't completed connect to start subscribe")
                return false
            }

            guard !self.isSubscribed else {
                Self.logger.warning("💼 Subscriber has already subscribed")
                return false
            }
            
            let options = MCClientOptions()
            options.forcePlayoutDelay = true
            self.subscriber.setOptions(options)
            
            guard self.subscriber.subscribe() else {
                Self.logger.warning("💼 Subscribe call has failed")
                return false
            }

            self.subscriber.enableStats(true)
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
            subscriber.enableStats(false)

            guard subscriber.unsubscribe() else {
                Self.logger.warning("💼 Failed to unsubscribe")
                return false
            }

            guard subscriber.disconnect() else {
                Self.logger.warning("💼 Failed to disconnect")
                return false
            }

            self.subscriber = nil

            return true
        }
        return await task.value
    }

    func selectVideoQuality(_ quality: StreamSource.VideoQuality, for source: StreamSource) {
        Self.logger.warning("💼 Select Video Quality \(quality.description) \(source.sourceId.value ?? "MAIN")")
        projectVideo(for: source, withQuality: quality)
    }

    func addRemoteTrack(_ sourceBuilder: StreamSourceBuilder) {
        Self.logger.warning("💼 Add remote track for source - \(sourceBuilder.sourceId.value ?? "MAIN")")
        sourceBuilder.supportedTrackItems.forEach { subscriber.addRemoteTrack($0.mediaType.rawValue) }
    }

    func projectVideo(for source: StreamSource, withQuality quality: StreamSource.VideoQuality) {
        Self.logger.debug("💼 Project video for source \(source.sourceId.value ?? "N/A")")
        let videoTrack = source.videoTrack
        let projectionData = MCProjectionData()
        projectionData.media = videoTrack.trackInfo.mediaType.rawValue
        projectionData.mid = videoTrack.trackInfo.mid
        projectionData.trackId = videoTrack.trackInfo.trackID
        projectionData.layer = quality.layerData

        print(">>>> video mid", videoTrack.trackInfo.mid)
        subscriber.project(source.sourceId.value, withData: [projectionData])
    }

    func unprojectVideo(for source: StreamSource) {
        Self.logger.debug("💼 Project video for source \(source.sourceId.value ?? "N/A")")
        let videoTrack = source.videoTrack
        subscriber.unproject([videoTrack.trackInfo.mid])
    }

    func projectAudio(for source: StreamSource) {
        Self.logger.debug("💼 Project audio for source \(source.sourceId.value ?? "N/A")")
        guard let audioTrack = source.audioTracks.first else {
            return
        }

        Utils.configureAudioSession()
        let projectionData = MCProjectionData()
        audioTrack.track.enable(true)
        audioTrack.track.setVolume(1)
        projectionData.media = audioTrack.trackInfo.mediaType.rawValue
        projectionData.mid = audioTrack.trackInfo.mid
        projectionData.trackId = audioTrack.trackInfo.trackID

        print(">>>> audio mid", audioTrack.trackInfo.mid)
        subscriber.project(source.sourceId.value, withData: [projectionData])
    }

    func unprojectAudio(for source: StreamSource) {
        guard let audioTrack = source.audioTracks.first else {
            return
        }

        subscriber.unproject([audioTrack.trackInfo.mid])
    }
}

// MARK: Maker functions

private extension SubscriptionManager {

    func makeSubscriber() -> MCSubscriber {
        return MCSubscriber.create()
    }

    func makeCredentials(streamName: String, accountID: String) -> MCSubscriberCredentials {
        let credentials = MCSubscriberCredentials()
        credentials.accountId = accountID
        credentials.streamName = streamName
        credentials.token = ""
        credentials.apiUrl = Defaults.subscribeURL

        return credentials
    }
}

// MARK: MCSubscriberListener implementation

extension SubscriptionManager: MCSubscriberListener {
    func onFrameMetadata(_ data: UnsafePointer<UInt8>!, withLength length: Int32, withSsrc ssrc: Int32, withTimestamp timestamp: Int32) {
        
    }
    
    func onDisconnected() {
        
    }
    

    func onSubscribed() {
        Self.logger.debug("💼 Delegate - onSubscribed")
        delegate?.onSubscribed()
    }

    func onSubscribedError(_ reason: String!) {
        Self.logger.error("💼 Delegate - onSubscribedError \(reason)")
        delegate?.onSubscribedError(reason)
    }

    func onVideoTrack(_ track: MCVideoTrack!, withMid mid: String!) {
        Self.logger.debug("💼 Delegate - onVideoTrack with mid \(mid)")
        delegate?.onVideoTrack(track, withMid: mid)
    }

    func onAudioTrack(_ track: MCAudioTrack!, withMid mid: String!) {
        Self.logger.debug("💼 Delegate - onAudioTrack with mid \(mid)")
        delegate?.onAudioTrack(track, withMid: mid)
    }

    func onActive(_ streamId: String!, tracks: [String]!, sourceId: String!) {
        Self.logger.debug("Callback -> onActive with sourceId \(sourceId ?? "NULL"), tracks - \(tracks)")
        delegate?.onActive(streamId, tracks: tracks, sourceId: sourceId)
    }

    func onInactive(_ streamId: String!, sourceId: String!) {
        Self.logger.debug("💼 Delegate - onInactive with sourceId \(sourceId ?? "NULL")")
        delegate?.onInactive(streamId, sourceId: sourceId)
    }

    func onStopped() {
        Self.logger.debug("💼 Delegate - onStopped")
        delegate?.onStopped()
    }

    func onVad(_ mid: String!, sourceId: String!) {
        Self.logger.debug("💼 Delegate - onVad with mid \(mid), sourceId \(sourceId)")
    }

    func onLayers(_ mid: String!, activeLayers: [MCLayerData]!, inactiveLayers: [MCLayerData]!) {
        Self.logger.debug("💼 Delegate - onLayers for mid - \(mid) with activeLayers \(activeLayers), inactiveLayers \(inactiveLayers)")
        delegate?.onLayers(mid, activeLayers: activeLayers, inactiveLayers: inactiveLayers)
    }

    func onConnected() {
        Self.logger.debug("💼 Delegate - onConnected")
        delegate?.onConnected()
    }

    func onConnectionError(_ status: Int32, withReason reason: String!) {
        Self.logger.error("💼 Delegate - onConnectionError")
        delegate?.onConnectionError(status, withReason: reason)
    }

    func onSignalingError(_ message: String!) {
        Self.logger.error("💼 Delegate - onSignalingError")
        delegate?.onSignalingError(message)
    }

    func onStatsReport(_ report: MCStatsReport!) {
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
