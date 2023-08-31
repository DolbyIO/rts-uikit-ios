//
//  StreamOrchestrator.swift
//

import Combine
import Foundation
import MillicastSDK
import os

@globalActor
public final actor StreamOrchestrator {
    public struct Configuration {
        let retryOnConnectionError = true
    }
    
    private static let logger = Logger.make(category: String(describing: StreamOrchestrator.self))
    
    private enum Defaults {
        static let retryConnectionTimeInterval = 5.0
    }
    
    public static let shared: StreamOrchestrator = StreamOrchestrator()
    
    private let stateMachine: StateMachine = StateMachine(initialState: .disconnected)
    private let subscriptionManager: SubscriptionManagerProtocol
    private let rendererRegistry: RendererRegistryProtocol
    private let taskScheduler: TaskSchedulerProtocol
    private let logHandler: MillicastLoggerHandler
    private let networkMonitor: NetworkMonitor

    private var subscriptions: Set<AnyCancellable> = []
    private lazy var stateSubject: CurrentValueSubject<StreamState, Never> = CurrentValueSubject(.disconnected)
    public lazy var statePublisher: AnyPublisher<StreamState, Never> = stateSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    public private(set) var activeStreamDetail: StreamDetail?
    
    private static var configuration: StreamOrchestrator.Configuration = .init()
    
    private var dev = false
    private var forcePlayoutDelay = false
    private var disableAudio = false
    private var jitterBufferDelay = 0
    private var documentDirectoryPath: String? = nil
    private var networkSubscription: AnyCancellable?

    private init() {
        self.init(
            subscriptionManager: SubscriptionManager(),
            taskScheduler: TaskScheduler(),
            rendererRegistry: RendererRegistry(),
            networkMonitor: NetworkMonitor.shared
        )
    }
    
    static func setStreamOrchestratorConfiguration(_ configuration: StreamOrchestrator.Configuration) {
        Self.configuration = configuration
    }
    
    init(
        subscriptionManager: SubscriptionManagerProtocol,
        taskScheduler: TaskSchedulerProtocol,
        rendererRegistry: RendererRegistryProtocol,
        networkMonitor: NetworkMonitor
    ) {
        self.subscriptionManager = subscriptionManager
        self.taskScheduler = taskScheduler
        self.rendererRegistry = rendererRegistry
        self.logHandler = MillicastLoggerHandler()
        self.networkMonitor = networkMonitor
        
        self.subscriptionManager.delegate = self
        
        Utils.configureAudioSession()

        Task { [weak self] in
            guard let self = self else { return }
            await self.startStateObservation()
        }
    }
    
    public func connect(
        streamName: String,
        accountID: String,
        dev: Bool,
        forcePlayoutDelay: Bool,
        disableAudio: Bool,
        jitterBufferDelay: Int,
        documentDirectoryPath: String?
    ) async -> Bool {
        Self.logger.error("👮‍♂️ Start subscribe")
        self.startNetworkObserver()
        
        self.dev = dev
        self.forcePlayoutDelay = forcePlayoutDelay
        self.disableAudio = disableAudio
        self.jitterBufferDelay = jitterBufferDelay
        self.documentDirectoryPath = documentDirectoryPath
        
        let timeStamp = Utils.getISO8601TimestampForCurrentDate()

        self.logHandler.updateLogFileDetail(
            documentDirectoryPath: documentDirectoryPath,
            subscribeTimeStamp: timeStamp
        )

        async let startConnectionStateUpdate: Void = stateMachine.startConnection(streamName: streamName, accountID: accountID)
        async let startConnection = subscriptionManager.connect(
            streamName: streamName,
            accountID: accountID,
            dev: dev,
            forcePlayoutDelay: forcePlayoutDelay,
            disableAudio: disableAudio,
            jitterBufferDelay: jitterBufferDelay,
            documentDirectoryPath: documentDirectoryPath,
            subscribeTimeStamp: timeStamp
        )
        
        let (_, connectionResult) = await (startConnectionStateUpdate, startConnection)
        if connectionResult {
            activeStreamDetail = StreamDetail(streamName: streamName, accountID: accountID)
        }
        return connectionResult
    }
    
    public func stopConnection() async -> Bool {
        Self.logger.error("👮‍♂️ Stop subscribe")
        activeStreamDetail = nil
        networkSubscription = nil
        async let stopSubscribeOnStateMachine: Void = stateMachine.stopSubscribe()
        async let resetRegistry: Void = rendererRegistry.reset()
        async let stopSubscription: Bool = await subscriptionManager.stopSubscribe()
        let (_, _, stopSubscribeResult) = await (stopSubscribeOnStateMachine, resetRegistry, stopSubscription)
        return stopSubscribeResult
    }
    
    public func playAudio(for source: StreamSource) async {
        Self.logger.error("👮‍♂️ Play Audio for source - \(source.sourceId.value ?? "Main", privacy: .public)")
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                !matchingSource.isPlayingAudio
            else {
                return
            }
            
            for source in sources {
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
        Self.logger.error("👮‍♂️ Stop Audio for source - \(source.sourceId.value ?? "Main", privacy: .public)")
        
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                matchingSource.isPlayingAudio
            else {
                return
            }
            subscriptionManager.unprojectAudio(for: source)
            stateMachine.setPlayingAudio(false, for: source)
            
        default:
            return
        }
    }
    
    public func playVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer, with quality: VideoQuality) async {
        Self.logger.error("👮‍♂️ Play Video for source - \(source.sourceId.value ?? "Main") on renderer - \(renderer.id, privacy: .public)")
        
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
        networkSubscription = networkMonitor.$isReachable
            .sink { [weak self] hasConnection in
                guard let self = self, !hasConnection else { return }

                self.stateMachine.onConnectionError(1000, withReason: "")
            }
    }
    
    func startStateObservation() {
        stateMachine.statePublisher
            .sink { state in
                Task { [weak self] in
                    guard let self = self else { return }
                    switch state {
                    case .error, .stopped:
                        await self.scheduleReconnection()
                        
                    default:
                        // No-op
                        break
                    }
                    
                    // Populate updates public facing states
                    await self.stateSubject.send(StreamState(state: state))
                }
            }
            .store(in: &subscriptions)
    }
    
    func scheduleReconnection() {
        guard Self.configuration.retryOnConnectionError, let streamDetail = self.activeStreamDetail else {
            return
        }
        Self.logger.debug("👮‍♂️ Scheduling a reconnect")
        taskScheduler.scheduleTask(timeInterval: Defaults.retryConnectionTimeInterval) { [weak self] in
            guard let self = self else { return }
            
            Task {
                await self.startNetworkObserver()

                _ = await self.connect(
                    streamName: streamDetail.streamName,
                    accountID: streamDetail.accountID,
                    dev: self.dev,
                    forcePlayoutDelay: self.forcePlayoutDelay,
                    disableAudio: self.disableAudio,
                    jitterBufferDelay: self.jitterBufferDelay,
                    documentDirectoryPath: self.documentDirectoryPath
                )
                
                self.taskScheduler.invalidate()
            }
        }
    }
    
    func startSubscribe() async -> Bool {
        async let startSubscribeStateUpdate: Void = stateMachine.startSubscribe()
        async let startSubscribe = subscriptionManager.startSubscribe()
        let (_, success) = await (startSubscribeStateUpdate, startSubscribe)
        return success
    }
}

// MARK: SubscriptionManagerDelegate implementation

extension StreamOrchestrator: SubscriptionManagerDelegate {
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
    
    nonisolated func onStatsReport(_ report: MCStatsReport) {
        let stats = StreamingStatistics.build(report: report)
        //        stats.forEach {
        //            print(">>>>", $0.mid ?? "-", $0.statsInboundRtp?.kind ?? "-")
        //        }
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            self.stateMachine.onStatsReport(stats)
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
                guard let sourceBuilder = state.streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
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
            if let sourceId = sourceId {
                await self.stopAudio(for: sourceId)
            }
            
            self.stateMachine.onInactive(streamId, sourceId: sourceId)
        }
    }
    
    func stopAudio(for sourceId: String) {
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            if let source = sources.first (where: { $0.sourceId.value == sourceId }), source.isPlayingAudio {
                subscriptionManager.unprojectAudio(for: source)
            }
        default: break
        }
    }
}
