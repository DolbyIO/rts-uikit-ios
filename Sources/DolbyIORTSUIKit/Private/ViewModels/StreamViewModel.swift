//
//  StreamViewModel.swift
//

import Combine
import DolbyIORTSCore
import Foundation

// swiftlint:disable type_body_length
final class StreamViewModel: ObservableObject {

    enum State {
        case loading
        case success(displayMode: DisplayMode)
        case error(ErrorViewModel)

        fileprivate init(_ state: InternalState) {
            switch state {
            case .loading:
                self = .loading
            case let .success(
                displayMode: displayMode,
                sources: _,
                selectedVideoSource: _,
                selectedAudioSource: _,
                sourceAndViewRenderers: _,
                detailSourceAndViewRenderers: _,
                settings: _
            ):
                self = .success(displayMode: displayMode)
            case let .error(errorViewModel):
                self = .error(errorViewModel)
            }
        }
    }

    fileprivate enum InternalState {
        case loading
        case success(
            displayMode: DisplayMode,
            sources: [StreamSource],
            selectedVideoSource: StreamSource,
            selectedAudioSource: StreamSource?,
            sourceAndViewRenderers: StreamSourceAndViewRenderers,
            detailSourceAndViewRenderers: StreamSourceAndViewRenderers,
            settings: StreamSettings
        )
        case error(ErrorViewModel)
    }

    enum DisplayMode {
        case single(SingleStreamViewModel)
        case list(ListViewModel)
    }

    private let settingsManager: SettingsManager
    private let streamOrchestrator: StreamOrchestrator
    private var subscriptions: [AnyCancellable] = []

    let streamDetail: StreamDetail?

    @Published private(set) var state: State = .loading

    private var internalState: InternalState = .loading {
        didSet {
            state = State(internalState)

            // Play Audio when the selectedAudioSource changes
            if let newlySelectedAudioSource = internalState.selectedAudioSource,
               newlySelectedAudioSource.id != oldValue.selectedAudioSource?.id {
                playAudio(for: newlySelectedAudioSource)
            }
        }
    }

    private var sources: [StreamSource] {
        switch internalState {
        case let .success(
            displayMode: _,
            sources: existingSources,
            selectedVideoSource: _,
            selectedAudioSource: _,
            sourceAndViewRenderers: _,
            detailSourceAndViewRenderers: _,
            settings: _
        ):
            return existingSources
        default:
            return []
        }
    }

    init(
        streamOrchestrator: StreamOrchestrator = .shared,
        settingsManager: SettingsManager = .shared
    ) {
        self.streamOrchestrator = streamOrchestrator
        self.settingsManager = settingsManager
        self.streamDetail = streamOrchestrator.activeStreamDetail
        if let streamId = streamOrchestrator.activeStreamDetail?.streamId {
            settingsManager.setActiveSettings(for: .stream(streamID: streamId))
        }

        startObservers()
    }

    var detailSingleStreamViewModel: SingleStreamViewModel? {
        switch internalState {
        case let .success(
            displayMode: _,
            sources: sources,
            selectedVideoSource: selectedVideoSource,
            selectedAudioSource: selectedAudioSource,
            sourceAndViewRenderers: _,
            detailSourceAndViewRenderers: existingDetailSourceAndViewRenderers,
            settings: _
        ):
            return SingleStreamViewModel(
                videoViewModels: sources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        viewRenderer: existingDetailSourceAndViewRenderers.primaryRenderer(for: $0),
                        isSelectedVideoSource: $0 == selectedVideoSource,
                        isSelectedAudioSource: $0 == selectedAudioSource,
                        showSourceLabel: false,
                        showAudioIndicator: false
                    )
                },
                selectedVideoSource: selectedVideoSource
            )

        default:
            return nil
        }
    }

    // swiftlint:disable function_body_length
    func selectVideoSource(_ source: StreamSource) {
        switch internalState {
        case let .success(
            displayMode: displayMode,
            sources: sources,
            selectedVideoSource: _,
            selectedAudioSource: _,
            sourceAndViewRenderers: sourceAndViewRenderers,
            detailSourceAndViewRenderers: detailSourceAndViewRenderers,
            settings: settings
        ):
            guard let matchingSource = sources.first(where: { $0.id == source.id }) else {
                fatalError("Cannot select source thats not part of the current source list")
            }

            let selectedAudioSource = audioSelection(from: sources, settings: settings, selectedVideoSource: matchingSource)

            let updatedDisplayMode: DisplayMode
            switch displayMode {
            case .list:
                let secondaryVideoSources = sources.filter { $0.id != matchingSource.id }
                let showSourceLabels = settings.showSourceLabels

                let listViewModel = ListViewModel(
                    primaryVideoViewModel: VideoRendererViewModel(
                        streamSource: matchingSource,
                        viewRenderer: sourceAndViewRenderers.primaryRenderer(for: matchingSource),
                        isSelectedVideoSource: true,
                        isSelectedAudioSource: matchingSource.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: matchingSource.id == selectedAudioSource?.id
                    ),
                    secondaryVideoViewModels: secondaryVideoSources.map {
                        VideoRendererViewModel(
                            streamSource: $0,
                            viewRenderer: sourceAndViewRenderers.secondaryRenderer(for: $0),
                            isSelectedVideoSource: false,
                            isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                            showSourceLabel: showSourceLabels,
                            showAudioIndicator: $0.id == selectedAudioSource?.id
                        )
                    }
                )

                updatedDisplayMode = .list(listViewModel)
            case .single:
                let singleStreamViewModel = SingleStreamViewModel(
                    videoViewModels: sources.map {
                        VideoRendererViewModel(
                            streamSource: $0,
                            viewRenderer: sourceAndViewRenderers.primaryRenderer(for: $0),
                            isSelectedVideoSource: $0.id == matchingSource.id,
                            isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                            showSourceLabel: false,
                            showAudioIndicator: false
                        )
                    },
                    selectedVideoSource: matchingSource
                )
                updatedDisplayMode = .single(singleStreamViewModel)
            }

            internalState = .success(
                displayMode: updatedDisplayMode,
                sources: sources,
                selectedVideoSource: matchingSource,
                selectedAudioSource: selectedAudioSource,
                sourceAndViewRenderers: sourceAndViewRenderers,
                detailSourceAndViewRenderers: detailSourceAndViewRenderers,
                settings: settings
            )
        default:
            fatalError("Cannot select source when the state is not `.success`")
        }
    }
    // swiftlint:enable function_body_length

    func endStream() async {
        _ = await streamOrchestrator.stopConnection()
        settingsManager.setActiveSettings(for: .global)
    }

    func playAudio(for source: StreamSource) {
        Task {
            await self.streamOrchestrator.playAudio(for: source)
        }
    }

    func stopAudio(for source: StreamSource) {
        Task {
            await self.streamOrchestrator.stopAudio(for: source)
        }
    }

    private func startObservers() {
        streamOrchestrator.statePublisher
            .combineLatest(settingsManager.settingsPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, settings in
                guard let self = self else { return }
                switch state {
                case let .subscribed(sources: sources, numberOfStreamViewers: _):
                    self.updateState(from: sources, settings: settings)
                case .connecting, .subscribing, .connected:
                    self.internalState = .loading
                case let .error(streamError):
                    self.internalState = .error(ErrorViewModel(error: streamError))
                case .stopped:
                    self.internalState = .error(.streamOffline)
                default:
                    // Handle's scenario where there is no sources
                    self.internalState = .error(.genericError)
                }
            }
            .store(in: &subscriptions)
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    private func updateState(from sources: [StreamSource], settings: StreamSettings) {
        guard !sources.isEmpty else {
            return
        }
                
        updateStreamSettings(from: sources, settings: settings)

        let sortedSources: [StreamSource]
        switch settings.streamSortOrder {
        case .connectionOrder:
            sortedSources = sources
        case .alphaNumeric:
            sortedSources = sources.sorted { $0 < $1 }
        }

        let selectedVideoSource: StreamSource
        let sourceAndViewRenderers: StreamSourceAndViewRenderers
        let detailSourceAndViewRenderers: StreamSourceAndViewRenderers

        switch internalState {
        case .error, .loading:
            selectedVideoSource = sortedSources[0]
            sourceAndViewRenderers = StreamSourceAndViewRenderers()
            detailSourceAndViewRenderers = StreamSourceAndViewRenderers()

        case let .success(
            displayMode: _,
            sources: _,
            selectedVideoSource: currentlySelectedVideoSource,
            selectedAudioSource: _,
            sourceAndViewRenderers: existingSourceAndViewRenderers,
            detailSourceAndViewRenderers: existingDetailSourceAndViewRenderers,
            settings: _
        ):
            selectedVideoSource = sources.first { $0.id == currentlySelectedVideoSource.id } ?? sortedSources[0]
            sourceAndViewRenderers = existingSourceAndViewRenderers
            detailSourceAndViewRenderers = existingDetailSourceAndViewRenderers
        }

        let selectedAudioSource = audioSelection(from: sortedSources, settings: settings, selectedVideoSource: selectedVideoSource)

        let displayMode: DisplayMode
        switch settings.multiviewLayout {
        case .list:
            let secondaryVideoSources = sortedSources.filter { $0.id != selectedVideoSource.id }
            let showSourceLabels = settings.showSourceLabels

            let listViewModel = ListViewModel(
                primaryVideoViewModel: VideoRendererViewModel(
                    streamSource: selectedVideoSource,
                    viewRenderer: sourceAndViewRenderers.primaryRenderer(for: selectedVideoSource),
                    isSelectedVideoSource: true,
                    isSelectedAudioSource: selectedVideoSource.id == selectedAudioSource?.id,
                    showSourceLabel: showSourceLabels,
                    showAudioIndicator: selectedVideoSource.id == selectedAudioSource?.id
                ),
                secondaryVideoViewModels: secondaryVideoSources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        viewRenderer: sourceAndViewRenderers.secondaryRenderer(for: $0),
                        isSelectedVideoSource: false,
                        isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: $0.id == selectedAudioSource?.id
                    )
                }
            )

            displayMode = .list(listViewModel)
        case .single:
            let singleStreamViewModel = SingleStreamViewModel(
                videoViewModels: sortedSources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        viewRenderer: sourceAndViewRenderers.primaryRenderer(for: $0),
                        isSelectedVideoSource: $0.id == selectedVideoSource.id,
                        isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                        showSourceLabel: false,
                        showAudioIndicator: false
                    )
                },
                selectedVideoSource: selectedVideoSource
            )
            displayMode = .single(singleStreamViewModel)

        default:
            fatalError("Display mode is unhandled")
        }

        self.internalState = .success(
            displayMode: displayMode,
            sources: sortedSources,
            selectedVideoSource: selectedVideoSource,
            selectedAudioSource: selectedAudioSource,
            sourceAndViewRenderers: sourceAndViewRenderers,
            detailSourceAndViewRenderers: detailSourceAndViewRenderers,
            settings: settings
        )
    }

    private func updateStreamSettings(from sources: [StreamSource], settings: StreamSettings) {
        // Only update the settings when the sources change, only sources with at least one audio track
        let sourceIds = sources.filter { $0.audioTracksCount > 0 }.compactMap { $0.sourceId.value }
        if sourceIds != settingsManager.settings.audioSources {
            settingsManager.settings.audioSources = sourceIds

            // If source selected in settings is no longer available, update the settings
            if case let .source(sourceId) = settingsManager.settings.audioSelection {
                if !settingsManager.settings.audioSources.contains(sourceId) {
                    settingsManager.settings.audioSelection = .firstSource
                }
            }
        }
    }

    private func audioSelection(from sources: [StreamSource], settings: StreamSettings, selectedVideoSource: StreamSource) -> StreamSource? {
        // Get the sources with at least one audio track if none, uses the original sources list
        let sourcesWithAudio = sources.filter { $0.audioTracksCount > 0 }
        if sourcesWithAudio.isEmpty {
            return nil
        }
        let selectedAudioSource: StreamSource?
        switch settings.audioSelection {
        case .firstSource:
            selectedAudioSource = sourcesWithAudio[0]
        case .mainSource:
            // If no main source available, use first source as main
            selectedAudioSource = sourcesWithAudio.first(where: { $0.sourceId == StreamSource.SourceId.main }) ?? sourcesWithAudio[0]
        case .followVideo:
            // Use audio from the video source, if no audio track uses the last one used or just the 1st one
            selectedAudioSource = selectedVideoSource.audioTracksCount > 0 ? selectedVideoSource : internalState.selectedAudioSource
        case let .source(sourceId: sourceId):
            selectedAudioSource = sourcesWithAudio.first(where: { $0.sourceId.value == sourceId }) ?? sourcesWithAudio[0]
        }
        return selectedAudioSource
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

// swiftlint:enable type_body_length

fileprivate extension StreamViewModel.InternalState {
    var selectedAudioSource: StreamSource? {
        switch self {
        case let .success(
            displayMode: _,
            sources: _,
            selectedVideoSource: _,
            selectedAudioSource: currentlySelectedAudioSource,
            sourceAndViewRenderers: _,
            detailSourceAndViewRenderers: _,
            settings: _
        ):
            return currentlySelectedAudioSource
        default:
            return nil
        }
    }
}
