//
//  StreamOrchestrator.swift
//

import Combine
import Foundation
import MillicastSDK
import os

open class StreamOrchestrator {
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

    private var subscriptions: Set<AnyCancellable> = []
    private lazy var stateSubject: CurrentValueSubject<StreamState, Never> = CurrentValueSubject(.disconnected)
    public lazy var statePublisher: AnyPublisher<StreamState, Never> = stateSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    public private(set) var activeStreamDetail: StreamDetail?
    
    private typealias OrchestratorTask = Task<Void, Never>
    private var taskStreamContinuation: AsyncStream<OrchestratorTask>.Continuation?
    private static var configuration: StreamOrchestrator.Configuration = .init()
    
    private var dev = false
    private var forcePlayoutDelay = false
    private var disableAudio = false
    private var jitterBufferDelay = 0
    private var documentDirectoryPath: String? = nil
    
    private convenience init() {
        self.init(
            subscriptionManager: SubscriptionManager(),
            taskScheduler: TaskScheduler(),
            rendererRegistry: RendererRegistry()
        )
    }
    
    static func setStreamOrchestratorConfiguration(_ configuration: StreamOrchestrator.Configuration) {
        Self.configuration = configuration
    }
    
    init(
        subscriptionManager: SubscriptionManagerProtocol,
        taskScheduler: TaskSchedulerProtocol,
        rendererRegistry: RendererRegistryProtocol
    ) {
        self.subscriptionManager = subscriptionManager
        self.taskScheduler = taskScheduler
        self.rendererRegistry = rendererRegistry
        self.logHandler = MillicastLoggerHandler()
        
        self.subscriptionManager.delegate = self
        
        startStateObservation()
        startStateMachineTasksSerialExecutor()
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
        async let stopSubscribeOnStateMachine: Void = stateMachine.stopSubscribe()
        async let resetRegistry: Void = rendererRegistry.reset()
        async let stopSubscription: Bool = await subscriptionManager.stopSubscribe()
        let (_, _, stopSubscribeResult) = await (stopSubscribeOnStateMachine, resetRegistry, stopSubscription)
        return stopSubscribeResult
    }
    
    public func selectVideoQuality(_ quality: StreamSource.VideoQuality, for source: StreamSource) {
        Self.logger.error("👮‍♂️ Select video quality \(quality.description) for source - \(source.sourceId.value ?? "Main", privacy: .public)")
        subscriptionManager.selectVideoQuality(quality, for: source)
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
            await withTaskGroup(of: Void.self) { [weak self] group in
                guard let self = self else { return }
                
                for source in sources {
                    guard source.isPlayingAudio else {
                        continue
                    }
                    
                    group.addTask {
                        await self.stateMachine.setPlayingAudio(false, for: source)
                        self.subscriptionManager.unprojectAudio(for: source)
                    }
                }
                
                group.addTask {
                    self.subscriptionManager.projectAudio(for: source)
                    await self.stateMachine.setPlayingAudio(true, for: source)
                }
            }
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
            await stateMachine.setPlayingAudio(false, for: source)
            
        default:
            return
        }
    }
    
    public func playVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer, quality: StreamSource.VideoQuality) async {
        Self.logger.error("👮‍♂️ Play Video for source - \(source.sourceId.value ?? "Main") on renderer - \(renderer.id, privacy: .public)")
        
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id })
            else {
                return
            }
            let videoTrack = matchingSource.videoTrack.track
            await rendererRegistry.registerRenderer(renderer, for: videoTrack)
            
            if !matchingSource.isPlayingVideo {
                subscriptionManager.projectVideo(for: matchingSource, withQuality: .auto)
                _ = await (
                    stateMachine.setPlayingVideo(true, for: matchingSource),
                    stateMachine.selectVideoQuality(.auto, for: matchingSource)
                )
            } else {
                let hasAlreadySetToIdealVideoQuality: Bool
                switch matchingSource.preferredVideoQuality {
                case .auto:
                    hasAlreadySetToIdealVideoQuality = false
                case .high:
                    hasAlreadySetToIdealVideoQuality = false
                case .medium:
                    hasAlreadySetToIdealVideoQuality = false
                case .low:
                    hasAlreadySetToIdealVideoQuality = true
                }
                
                guard !hasAlreadySetToIdealVideoQuality, let qualityToProject = matchingSource.availableVideoQualityList.first(where: { quality in
                    switch quality {
                    case .auto:
                        return false
                    case .high:
                        return false
                    case .medium:
                        return false
                    case .low:
                        return true
                    }
                }) else {
                    return
                }
                subscriptionManager.projectVideo(for: matchingSource, withQuality: qualityToProject)
                _ = await (
                    stateMachine.setPlayingVideo(true, for: matchingSource),
                    stateMachine.selectVideoQuality(qualityToProject, for: matchingSource)
                )
            }

        default:
            return
        }
    }
    
    public func stopVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer) async {
        Self.logger.error("👮‍♂️ Stop Video for source - \(source.sourceId.value ?? "Main") on renderer - \(renderer.id, privacy: .public)")
        
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                matchingSource.isPlayingVideo
            else {
                return
            }
            let videoTrack = source.videoTrack.track
            await rendererRegistry.deregisterRenderer(renderer, for: videoTrack)
            
            let hasActiveRenderer = await rendererRegistry.hasActiveRenderer(for: videoTrack)
            if !hasActiveRenderer {
                subscriptionManager.unprojectVideo(for: source)
                await stateMachine.setPlayingVideo(false, for: source)
            }
        default:
            return
        }
    }
}

// MARK: Private helper methods

private extension StreamOrchestrator {
    
    func startStateObservation() {
        Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.statePublisher
                .sink { state in
                    switch state {
                    case .error, .stopped:
                        Task { [weak self] in
                            guard
                                let self = self,
                                let streamDetail = self.activeStreamDetail
                            else {
                                return
                            }

                            self.scheduleReconnection(with: streamDetail.streamName, accountID: streamDetail.accountID)
                        }
                    case .connected:
                        self.invalidateScheduleReconnections()
                        Task { [weak self] in
                            guard let self = self else { return }
                            _ = await self.startSubscribe()
                        }

                    case .subscribed:
                        self.invalidateScheduleReconnections()
                        
                    default:
                        // No-op
                        break
                    }
                    
                    // Populate updates public facing states
                    self.stateSubject.send(StreamState(state: state))
                }
                .store(in: &subscriptions)
        }
    }
    
    func scheduleReconnection(with streamName: String, accountID: String) {
        guard Self.configuration.retryOnConnectionError else {
            return
        }

        Self.logger.error("👮‍♂️ Scheduling a reconnect")
        taskScheduler.scheduleTask(timeInterval: Defaults.retryConnectionTimeInterval) { [weak self] in
            guard let self = self else { return }
            Task {
                _ = await self.connect(
                    streamName: streamName,
                    accountID: accountID,
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
    
    func invalidateScheduleReconnections() {
        self.taskScheduler.invalidate()
    }
    
    func startStateMachineTasksSerialExecutor() {
        Self.logger.error("👮‍♂️ Start serial task executor")
        Task { [weak self] in
            guard let self = self else { return }
            
            let taskStream = AsyncStream<OrchestratorTask> { continuation in
                self.taskStreamContinuation = continuation
            }
            
            for await task in taskStream {
                await task.value
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
    public func onSubscribedError(_ reason: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onSubscribedError(reason)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onSignalingError(_ message: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onSignalingError(message)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onConnectionError(_ status: Int32, withReason reason: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onConnectionError(status, withReason: reason)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onStopped() {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onStopped()
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onConnected() {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onConnected()
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onSubscribed() {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onSubscribed()
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onVideoTrack(_ track: MCVideoTrack, withMid mid: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onVideoTrack(track, withMid: mid)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onAudioTrack(_ track: MCAudioTrack, withMid mid: String) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onAudioTrack(track, withMid: mid)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onStatsReport(_ report: MCStatsReport) {
        let stats = StreamingStatistics.build(report: report)
        //        stats.forEach {
        //            print(">>>>", $0.mid ?? "-", $0.statsInboundRtp?.kind ?? "-")
        //        }
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onStatsReport(stats)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onViewerCount(_ count: Int32) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.updateNumberOfStreamViewers(count)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onLayers(_ mid_: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData]) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onLayers(mid_, activeLayers: activeLayers, inactiveLayers: inactiveLayers)
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onActive(_ streamId: String, tracks: [String], sourceId: String?) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onActive(streamId, tracks: tracks, sourceId: sourceId)
            let stateMachineState = await self.stateMachine.currentState
            switch stateMachineState {
            case let .subscribed(state):
                guard let sourceBuilder = state.streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
                    return
                }
                // Ignore add remote call for the first source, using cached source
                if state.cachedSourceZeroVideoTrackAndMid != nil || state.cachedSourceZeroAudioTrackAndMid != nil {
                    self.subscriptionManager.addRemoteTrack(sourceBuilder)
                }
            default:
                return
            }
        }
        taskStreamContinuation?.yield(task)
    }
    
    public func onInactive(_ streamId: String, sourceId: String?) {
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.stateMachine.onInactive(streamId, sourceId: sourceId)
        }
        taskStreamContinuation?.yield(task)
    }
}
