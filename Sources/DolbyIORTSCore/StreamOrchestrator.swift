//
//  StreamOrchestrator.swift
//

import Combine
import Foundation
import MillicastSDK
import os

@globalActor
public final actor StreamOrchestrator {

    private static let logger = Logger.make(category: String(describing: StreamOrchestrator.self))

    private enum Defaults {
        static let retryConnectionTimeInterval = 5.0
    }

    public static let shared: StreamOrchestrator = StreamOrchestrator()

    private let stateMachine: StateMachine = StateMachine(initialState: .disconnected)
    private let subscriptionManager: SubscriptionManagerProtocol
    private let rendererRegistry: RendererRegistryProtocol
    private let networkMonitor: NetworkMonitor

    private var subscriptions: Set<AnyCancellable> = []
    private lazy var stateSubject: CurrentValueSubject<StreamState, Never> = CurrentValueSubject(.disconnected)
    public lazy var statePublisher: AnyPublisher<StreamState, Never> = stateSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    private var activeStreamDetail: StreamDetail?
    private let logHandler: MillicastLoggerHandler = .init()

    private init() {
        self.init(
            subscriptionManager: SubscriptionManager(),
            rendererRegistry: RendererRegistry(),
            networkMonitor: .shared
        )
    }
    
    init(
        subscriptionManager: SubscriptionManagerProtocol,
        rendererRegistry: RendererRegistryProtocol,
        networkMonitor: NetworkMonitor
    ) {
        self.subscriptionManager = subscriptionManager
        self.rendererRegistry = rendererRegistry
        self.networkMonitor = networkMonitor

        self.subscriptionManager.delegate = self

        Utils.configureAudioSession()

        Task { [weak self] in
            guard let self = self else { return }
            await self.startStateObservation()
        }
    }

    public func connect(streamName: String, accountID: String, configuration: SubscriptionConfiguration = .init()) async -> Bool {
        Self.logger.debug("👮‍♂️ Start subscribe")
        logHandler.setLogFilePath(filePath: configuration.sdkLogPath)
        networkMonitor.startMonitoring()
        
        async let startConnectionStateUpdate: Void = stateMachine.startConnection(streamName: streamName, accountID: accountID)
        async let startConnection = subscriptionManager.connect(streamName: streamName, accountID: accountID, configuration: configuration)
        
        let (_, connectionResult) = await (startConnectionStateUpdate, startConnection)
        if connectionResult {
            activeStreamDetail = StreamDetail(streamName: streamName, accountID: accountID)
        } else {
            activeStreamDetail = nil
        }
        return connectionResult
    }

    public func stopConnection() async -> Bool {
        Self.logger.debug("👮‍♂️ Stop subscribe")
        reset()
        
        async let stopSubscribeOnStateMachine: Void = stateMachine.stopSubscribe()
        async let resetRegistry: Void = rendererRegistry.reset()
        async let stopSubscription: Bool = await subscriptionManager.stopSubscribe()
        let (_, _, stopSubscribeResult) = await (stopSubscribeOnStateMachine, resetRegistry, stopSubscription)
        return stopSubscribeResult
    }

    public func playAudio(for source: StreamSource) async {
        Self.logger.debug("👮‍♂️ Play Audio for source - \(String(describing: source.sourceId.value))")
        switch stateMachine.currentState {
        case let .subscribed(subscribedState):
            guard
                let matchingSource = subscribedState.sources.first(where: { $0.id == source.id }),
                !matchingSource.isPlayingAudio
            else {
                return
            }
            for source in subscribedState.sources {
                guard source.isPlayingAudio else {
                    continue
                }
                
                stateMachine.setPlayingAudio(false, for: source)
                subscriptionManager.unprojectAudio(for: source)
            }
            
            subscriptionManager.projectAudio(for: source)
            stateMachine.setPlayingAudio(true, for: source)
        default:
            return
        }
    }

    public func stopAudio(for source: StreamSource) async {
        Self.logger.debug("👮‍♂️ Stop Audio for source - \(String(describing: source.sourceId.value))")

        switch stateMachine.currentState {
        case let .subscribed(subscribedState):
            guard
                let matchingSource = subscribedState.sources.first(where: { $0.id == source.id }),
                matchingSource.isPlayingAudio
            else {
                return
            }
            subscriptionManager.unprojectAudio(for: matchingSource)
            stateMachine.setPlayingAudio(false, for: matchingSource)

        default:
            return
        }
    }

    public func playVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer, with quality: VideoQuality) async {
        Self.logger.debug("👮‍♂️ Play Video for source - \(String(describing: source.sourceId.value)) on renderer - \(renderer.id) with quality - \(quality.description)")

        switch stateMachine.currentState {
        case let .subscribed(subscribedState):
            guard
                let matchingSource = subscribedState.sources.first(where: { $0.id == source.id })
            else {
                return
            }
            let videoTrack = matchingSource.videoTrack.track
            rendererRegistry.registerRenderer(renderer, with: quality)
            let requestedVideoQuality = rendererRegistry.requestedVideoQuality(for: videoTrack)
            let videoQualityToRender = matchingSource.videoQualityList.contains(requestedVideoQuality) ?
                requestedVideoQuality : .auto
            
            if !matchingSource.isPlayingVideo || matchingSource.selectedVideoQuality != videoQualityToRender {
                subscriptionManager.projectVideo(for: matchingSource, withQuality: videoQualityToRender)
                stateMachine.setPlayingVideo(true, for: matchingSource)
                stateMachine.selectVideoQuality(videoQualityToRender, for: matchingSource)
            }

        default:
            return
        }
    }

    public func stopVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer) async {
        Self.logger.debug("👮‍♂️ Stop Video for source - \(String(describing: source.sourceId.value)) on renderer - \(renderer.id)")

        switch stateMachine.currentState {
        case let .subscribed(subscribedState):
            guard
                let matchingSource = subscribedState.sources.first(where: { $0.id == source.id }),
                matchingSource.isPlayingVideo
            else {
                return
            }
            let videoTrack = matchingSource.videoTrack.track
            rendererRegistry.deregisterRenderer(renderer)

            let hasActiveRenderer = rendererRegistry.hasActiveRenderer(for: videoTrack)
            if !hasActiveRenderer {
                subscriptionManager.unprojectVideo(for: source)
                stateMachine.setPlayingVideo(false, for: matchingSource)
                stateMachine.onLayers(
                    matchingSource.videoTrack.trackInfo.mid,
                    activeLayers: [],
                    inactiveLayers: []
                )
            } else {
                let requestedVideoQuality = rendererRegistry.requestedVideoQuality(for: videoTrack)
                let videoQualityToRender = matchingSource.videoQualityList.contains(requestedVideoQuality) ?
                    requestedVideoQuality : .auto
                
                if matchingSource.selectedVideoQuality != videoQualityToRender {
                    subscriptionManager.projectVideo(for: matchingSource, withQuality: videoQualityToRender)
                    stateMachine.setPlayingVideo(true, for: matchingSource)
                    stateMachine.selectVideoQuality(videoQualityToRender, for: matchingSource)
                }
            }
            
        default:
            return
        }
    }
}

// MARK: Private helper methods

private extension StreamOrchestrator {
    func startNetworkObserver() {
        networkMonitor.$isReachable
            .removeDuplicates()
            .filter { $0 == true }
            .sink { _ in
                Task { @StreamOrchestrator [weak self] in
                    guard let self = self, let streamDetail = await self.activeStreamDetail else { return }

                    switch await self.stateSubject.value {
                    case .error(StreamError.connectFailed(reason: _)), .stopped:
                        await self.reconnectToStream(streamDetail: streamDetail)
                    default: break
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    func startStateObservation() {
        stateMachine.statePublisher
            .sink { state in
                Task { [weak self] in
                    guard let self = self else { return }
                    // Populate updates public facing states
                    await self.stateSubject.send(StreamState(state: state))
                }
            }
            .store(in: &subscriptions)
    }
    
    func reconnectToStream(streamDetail: StreamDetail) async {
        Self.logger.debug("👮‍♂️ Attempting a reconnect")
        _ = await connect(streamName: streamDetail.streamName, accountID: streamDetail.accountID)
    }

    func startSubscribe() async -> Bool {
        stateMachine.startSubscribe()
        return await subscriptionManager.startSubscribe()
    }
    
    func stopAudio(for sourceId: String?) {
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            if let source = sources.first (where: { $0.sourceId == StreamSource.SourceId(id: sourceId) }), source.isPlayingAudio {
                subscriptionManager.unprojectAudio(for: source)
            }
        default: break
        }
    }
    
    func reset() {
        activeStreamDetail = nil
        logHandler.setLogFilePath(filePath: nil)
        networkMonitor.startMonitoring()
    }
}

// MARK: SubscriptionManagerDelegate implementation

extension StreamOrchestrator: SubscriptionManagerDelegate {
    
    nonisolated func onDisconnected() {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onDisconnected()
        }
    }
    
    nonisolated func onSubscribedError(_ reason: String) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onSubscribedError(reason)
        }
    }

    nonisolated func onSignalingError(_ message: String) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onSignalingError(message)
        }
    }

    nonisolated func onConnectionError(_ status: Int32, withReason reason: String) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onConnectionError(status, withReason: reason)
        }
    }

    nonisolated func onStopped() {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onStopped()
        }
    }

    nonisolated func onConnected() {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onConnected()
            _ = await self.startSubscribe()
        }
    }

    nonisolated func onSubscribed() {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onSubscribed()
        }
    }

    nonisolated func onVideoTrack(_ track: MCVideoTrack, withMid mid: String) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onVideoTrack(track, withMid: mid)
        }
    }

    nonisolated func onAudioTrack(_ track: MCAudioTrack, withMid mid: String) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onAudioTrack(track, withMid: mid)
        }
    }

    nonisolated public func onStatsReport(_ report: MCStatsReport) {
        guard let streamingStats = AllStreamStatistics(report) else {
            return
        }
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onStatsReport(streamingStats)
        }
    }

    nonisolated func onViewerCount(_ count: Int32) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.updateNumberOfStreamViewers(count)
        }
    }

    nonisolated func onLayers(_ mid_: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData]) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onLayers(mid_, activeLayers: activeLayers, inactiveLayers: inactiveLayers)
        }
    }

    nonisolated func onActive(_ streamId: String, tracks: [String], sourceId: String?) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onActive(streamId, tracks: tracks, sourceId: sourceId)
            let stateMachineState = self.stateMachine.currentState
            switch stateMachineState {
            case let .subscribed(state):
                guard let sourceBuilder = state.streamSourceBuilders.first(where: { $0.sourceId == StreamSource.SourceId(id: sourceId) }) else {
                    return
                }
                self.subscriptionManager.addRemoteTrack(sourceBuilder)

            default:
                return
            }
        }
    }

    nonisolated func onInactive(_ streamId: String, sourceId: String?) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            
            // Unproject audio whose source is inactive
            await self.stopAudio(for: sourceId)

            self.stateMachine.onInactive(streamId, sourceId: sourceId)
        }
    }
}
