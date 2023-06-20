//
//  StreamCoordinator.swift
//

import Combine
import Foundation
import MillicastSDK
import os

open class StreamCoordinator {
    
    private enum Defaults {
        static let retryConnectionTimeInterval = 5.0
    }

    public static let shared: StreamCoordinator = StreamCoordinator()

    private let stateMachine: StateMachine = StateMachine(initialState: .disconnected)
    private let subscriptionManager: SubscriptionManagerProtocol
    private let rendererRegistry: RendererRegistryProtocol
    private let taskScheduler: TaskSchedulerProtocol

    private var subscriptions: Set<AnyCancellable> = []
    private lazy var stateSubject: CurrentValueSubject<StreamState, Never> = CurrentValueSubject(.disconnected)
    public lazy var statePublisher: AnyPublisher<StreamState, Never> = stateSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    public private(set) var activeStreamDetail: StreamDetail?

    private typealias CoordinatorTask = Task<Void, Never>
    private var coordinatorTasksContinuation: AsyncStream<CoordinatorTask>.Continuation?

    private convenience init() {
        self.init(
            subscriptionManager: SubscriptionManager(),
            taskScheduler: TaskScheduler(),
            rendererRegistry: RendererRegistry()
        )
    }

    init(
        subscriptionManager: SubscriptionManagerProtocol,
        taskScheduler: TaskSchedulerProtocol,
        rendererRegistry: RendererRegistryProtocol
    ) {
        self.subscriptionManager = subscriptionManager
        self.taskScheduler = taskScheduler
        self.rendererRegistry = rendererRegistry

        self.subscriptionManager.delegate = self

        startStateObservation()
        startStateMachineTasksSerialExecutor()
    }

    private func startStateObservation() {
        Task {
            await stateMachine.statePublisher
                .sink { [weak self] state in
                    guard let self = self else { return }
                    
                    switch state {
                    case let .error(state):
                        switch state.error {
                        case .connectFailed:
                            self.scheduleReconnection()
                        default:
                            //No-op
                            break
                        }
                    case .stopped:
                        self.scheduleReconnection()
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
    
    private func scheduleReconnection() {
        taskScheduler.scheduleTask(timeInterval: Defaults.retryConnectionTimeInterval) { [weak self] in
            guard let self = self, let streamDetail = self.activeStreamDetail else { return }
            Task {
                self.taskScheduler.invalidate()
                _ = await self.connect(
                    streamName: streamDetail.streamName,
                    accountID: streamDetail.accountID
                )
            }
        }
    }
    
    private func startStateMachineTasksSerialExecutor() {
        Task {
            let tasksStreams = AsyncStream<CoordinatorTask> { continuation in
                self.coordinatorTasksContinuation = continuation
            }
            
            for await task in tasksStreams {
                await task.value
            }
        }
    }

    // MARK: Subscribe API methods

    public func connect(streamName: String, accountID: String) async -> Bool {
        async let startConnectionStateUpdate: Void = stateMachine.startConnection(streamName: streamName, accountID: accountID)
        async let startConnection = subscriptionManager.connect(streamName: streamName, accountID: accountID)
        
        let (_, connectionResult) = await (startConnectionStateUpdate, startConnection)
        if connectionResult {
            activeStreamDetail = StreamDetail(streamName: streamName, accountID: accountID)
        }
        return connectionResult
    }

    public func stopConnection() async -> Bool {
        activeStreamDetail = nil
        async let stopSubscribeOnStateMachine: Void = stateMachine.stopSubscribe()
        async let resetRegistry: Void = rendererRegistry.reset()
        async let stopSubscription: Bool = await subscriptionManager.stopSubscribe()
        let (_, _, stopSubscribeResult) = await (stopSubscribeOnStateMachine, resetRegistry, stopSubscription)
        return stopSubscribeResult
    }

    public func selectVideoQuality(_ quality: StreamSource.VideoQuality, for source: StreamSource) {
        subscriptionManager.selectVideoQuality(quality, for: source)
    }

    public func playAudio(for source: StreamSource) async {
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                !matchingSource.isPlayingAudio
            else {
                return
            }
            await withTaskGroup(of: Void.self) { group in
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
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                let videoTrack = source.videoTrack?.track
            else {
                return
            }
            await rendererRegistry.registerRenderer(renderer, for: videoTrack)

            if !matchingSource.isPlayingVideo {
                subscriptionManager.projectVideo(for: source, withQuality: quality)
                _ = await (
                    stateMachine.setPlayingVideo(true, for: source),
                    stateMachine.selectVideoQuality(quality, for: source)
                )
            }

        default:
            return
        }
    }

    public func stopVideo(for source: StreamSource, on renderer: StreamSourceViewRenderer) async {
        switch stateSubject.value {
        case let .subscribed(sources: sources, numberOfStreamViewers: _):
            guard
                let matchingSource = sources.first(where: { $0.id == source.id }),
                matchingSource.isPlayingVideo,
                let videoTrack = source.videoTrack?.track
            else {
                return
            }
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

private extension StreamCoordinator {
    func startSubscribe() async -> Bool {
        async let startSubscribeStateUpdate: Void = stateMachine.startSubscribe()
        async let startSubscribe = subscriptionManager.startSubscribe()
        let (_, success) = await (startSubscribeStateUpdate, startSubscribe)
        return success
    }
}

// MARK: SubscriptionManagerDelegate implementation

extension StreamCoordinator: SubscriptionManagerDelegate {
    public func onSubscribedError(_ reason: String) {
        let task = Task {
            await stateMachine.onSubscribedError(reason)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onSignalingError(_ message: String) {
        let task = Task {
            await stateMachine.onSignalingError(message)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onConnectionError(_ status: Int32, withReason reason: String) {
        let task = Task {
            await stateMachine.onConnectionError(status, withReason: reason)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onStopped() {
        let task = Task {
            await stateMachine.onStopped()
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onConnected() {
        let task = Task {
            await stateMachine.onConnected()
            _ = await startSubscribe()
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onSubscribed() {
        let task = Task {
            await stateMachine.onSubscribed()
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onVideoTrack(_ track: MCVideoTrack, withMid mid: String) {
        let task = Task { [weak self] in
            guard let self = self else {
                return
            }
            await self.stateMachine.onVideoTrack(track, withMid: mid)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onAudioTrack(_ track: MCAudioTrack, withMid mid: String) {
        let task = Task {
            await stateMachine.onAudioTrack(track, withMid: mid)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onStatsReport(_ report: MCStatsReport) {
        guard let streamingStats = StreamingStatistics(report) else {
            return
        }
        let task = Task {
            await stateMachine.onStatsReport(streamingStats)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onViewerCount(_ count: Int32) {
        let task = Task {
            await stateMachine.updateNumberOfStreamViewers(count)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onLayers(_ mid_: String, activeLayers: [MCLayerData], inactiveLayers: [MCLayerData]) {
        let task = Task {
            await stateMachine.onLayers(mid_, activeLayers: activeLayers, inactiveLayers: inactiveLayers)
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onActive(_ streamId: String, tracks: [String], sourceId: String?) {
        let task = Task {
            await stateMachine.onActive(streamId, tracks: tracks, sourceId: sourceId)
            let stateMachineState = await stateMachine.currentState
            switch stateMachineState {
            case let .subscribed(state):
                guard let sourceBuilder = state.streamSourceBuilders.first(where: { $0.sourceId.value == sourceId }) else {
                    return
                }
                subscriptionManager.addRemoteTrack(sourceBuilder)
            default:
                return
            }
        }
        coordinatorTasksContinuation?.yield(task)
    }

    public func onInactive(_ streamId: String, sourceId: String?) {
        let task = Task { [weak self] in
            guard let self = self else {
                return
            }
            await self.stateMachine.onInactive(streamId, sourceId: sourceId)
        }
        coordinatorTasksContinuation?.yield(task)
    }
}
