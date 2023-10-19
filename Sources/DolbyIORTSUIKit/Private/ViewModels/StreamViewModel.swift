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
            settings: StreamSettings
        )
        case error(ErrorViewModel)
    }

    enum DisplayMode {
        case single(SingleStreamViewModel)
        case list(ListViewModel)
        case grid(GridViewModel)
    }

    private let settingsManager: SettingsManager
    private let streamOrchestrator: StreamOrchestrator
    private var subscriptions: [AnyCancellable] = []

    let streamDetail: StreamDetail
    let settingsMode: SettingsMode
    let listViewPrimaryVideoQuality: VideoQuality

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
            settings: _
        ):
            return existingSources
        default:
            return []
        }
    }

    init(
        context: StreamingScreen.Context,
        listViewPrimaryVideoQuality: VideoQuality,
        streamOrchestrator: StreamOrchestrator = .shared,
        settingsManager: SettingsManager = .shared
    ) {
        self.streamOrchestrator = streamOrchestrator
        self.settingsManager = settingsManager
        self.streamDetail = context.streamDetail
        self.listViewPrimaryVideoQuality = context.listViewPrimaryVideoQuality
        self.settingsMode = .stream(streamName: streamDetail.streamName, accountID: streamDetail.accountID)

        startObservers()
    }

    var detailSingleStreamViewModel: SingleStreamViewModel? {
        switch internalState {
        case let .success(
            displayMode: _,
            sources: sources,
            selectedVideoSource: selectedVideoSource,
            selectedAudioSource: selectedAudioSource,
            settings: _
        ):
            return SingleStreamViewModel(
                videoViewModels: sources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        isSelectedVideoSource: $0 == selectedVideoSource,
                        isSelectedAudioSource: $0 == selectedAudioSource,
                        showSourceLabel: false,
                        showAudioIndicator: false,
                        videoQuality: .auto
                    )
                },
                selectedVideoSource: selectedVideoSource,
                streamDetail: streamDetail
            )

        default:
            return nil
        }
    }

    private func secondaryVideoSources(_ sources: [StreamSource], _ matchingSource: StreamSource) -> [StreamSource] {
        return sources.filter { $0.id != matchingSource.id }
    }

    // swiftlint:disable function_body_length
    func selectVideoSource(_ source: StreamSource) {
        switch internalState {
        case let .success(
            displayMode: displayMode,
            sources: sources,
            selectedVideoSource: _,
            selectedAudioSource: _,
            settings: settings
        ):
            guard let matchingSource = sources.first(where: { $0.id == source.id }) else {
                fatalError("Cannot select source thats not part of the current source list")
            }

            let selectedAudioSource = audioSelection(from: sources, settings: settings, selectedVideoSource: matchingSource)

            let updatedDisplayMode: DisplayMode
            switch displayMode {
            case .grid:
                let secondaryVideoSources = secondaryVideoSources(sources, matchingSource)
                let showSourceLabels = settings.showSourceLabels
                
                let gridViewModel = GridViewModel(
                    primaryVideoViewModel: VideoRendererViewModel(
                        streamSource: matchingSource,
                        isSelectedVideoSource: true,
                        isSelectedAudioSource: matchingSource.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: matchingSource.id == selectedAudioSource?.id,
                        videoQuality: .auto
                    ),
                    secondaryVideoViewModels: secondaryVideoSources.map {
                        VideoRendererViewModel(
                            streamSource: $0,
                            isSelectedVideoSource: false,
                            isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                            showSourceLabel: showSourceLabels,
                            showAudioIndicator: $0.id == selectedAudioSource?.id,
                            videoQuality: $0.videoQualityList.contains(.low) ? .low : .auto
                        )
                    }
                )

                updatedDisplayMode = .grid(gridViewModel)
            case .list:
                let secondaryVideoSources = secondaryVideoSources(sources, matchingSource)
                let showSourceLabels = settings.showSourceLabels
                let primaryVideoQuality = matchingSource.videoQualityList.contains(listViewPrimaryVideoQuality) ? listViewPrimaryVideoQuality : .auto

                let listViewModel = ListViewModel(
                    primaryVideoViewModel: VideoRendererViewModel(
                        streamSource: matchingSource,
                        isSelectedVideoSource: true,
                        isSelectedAudioSource: matchingSource.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: matchingSource.id == selectedAudioSource?.id,
                        videoQuality: primaryVideoQuality
                    ),
                    secondaryVideoViewModels: secondaryVideoSources.map {
                        VideoRendererViewModel(
                            streamSource: $0,
                            isSelectedVideoSource: false,
                            isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                            showSourceLabel: showSourceLabels,
                            showAudioIndicator: $0.id == selectedAudioSource?.id,
                            videoQuality: $0.videoQualityList.contains(.low) ? .low : .auto
                        )
                    }
                )

                updatedDisplayMode = .list(listViewModel)
            case .single:
                let singleStreamViewModel = SingleStreamViewModel(
                    videoViewModels: sources.map {
                        VideoRendererViewModel(
                            streamSource: $0,
                            isSelectedVideoSource: $0.id == matchingSource.id,
                            isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                            showSourceLabel: false,
                            showAudioIndicator: false,
                            videoQuality: .auto
                        )
                    },
                    selectedVideoSource: matchingSource,
                    streamDetail: streamDetail
                )
                updatedDisplayMode = .single(singleStreamViewModel)
            }

            internalState = .success(
                displayMode: updatedDisplayMode,
                sources: sources,
                selectedVideoSource: matchingSource,
                selectedAudioSource: selectedAudioSource,
                settings: settings
            )
        default:
            fatalError("Cannot select source when the state is not `.success`")
        }
    }
    // swiftlint:enable function_body_length

    func endStream() async {
        _ = await streamOrchestrator.stopConnection()
    }

    func playAudio(for source: StreamSource) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            await self.streamOrchestrator.playAudio(for: source)
        }
    }

    func stopAudio(for source: StreamSource) {
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            await self.streamOrchestrator.stopAudio(for: source)
        }
    }

    private func startObservers() {
        let settingsPublisher = settingsManager.publisher(for: settingsMode)
        Task { @StreamOrchestrator [weak self] in
            guard let self = self else { return }
            await self.streamOrchestrator.statePublisher
                .combineLatest(settingsPublisher)
                .receive(on: DispatchQueue.main)
                .sink { state, settings in
                    switch state {
                    case let .subscribed(sources: sources, numberOfStreamViewers: _):
                        self.updateState(from: sources, settings: settings)
                    case .connecting, .subscribing, .connected:
                        self.internalState = .loading
                    case let .error(streamError):
                        self.internalState = .error(ErrorViewModel(error: streamError))
                    case .stopped:
                        self.internalState = .error(.streamOffline)
                    case .disconnected:
                        self.internalState = .error(.noInternet)
                    }
                }
                .store(in: &self.subscriptions)
        }
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

        switch internalState {
        case .error, .loading:
            selectedVideoSource = sortedSources[0]

        case let .success(
            displayMode: _,
            sources: _,
            selectedVideoSource: currentlySelectedVideoSource,
            selectedAudioSource: _,
            settings: _
        ):
            selectedVideoSource = sources.first { $0.id == currentlySelectedVideoSource.id } ?? sortedSources[0]
        }

        let selectedAudioSource = audioSelection(from: sources, settings: settings, selectedVideoSource: selectedVideoSource)

        let displayMode: DisplayMode
        switch settings.multiviewLayout {
        case .list:
            let secondaryVideoSources = sortedSources.filter { $0.id != selectedVideoSource.id }
            let showSourceLabels = settings.showSourceLabels
            let primaryVideoQuality = selectedVideoSource.videoQualityList.contains(listViewPrimaryVideoQuality) ? listViewPrimaryVideoQuality : .auto

            let listViewModel = ListViewModel(
                primaryVideoViewModel: VideoRendererViewModel(
                    streamSource: selectedVideoSource,
                    isSelectedVideoSource: true,
                    isSelectedAudioSource: selectedVideoSource.id == selectedAudioSource?.id,
                    showSourceLabel: showSourceLabels,
                    showAudioIndicator: selectedVideoSource.id == selectedAudioSource?.id,
                    videoQuality: primaryVideoQuality
                ),
                secondaryVideoViewModels: secondaryVideoSources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        isSelectedVideoSource: false,
                        isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: $0.id == selectedAudioSource?.id,
                        videoQuality: $0.videoQualityList.contains(.low) ? .low : .auto
                    )
                }
            )

            displayMode = .list(listViewModel)
        case .grid:
            let secondaryVideoSources = sortedSources.filter { $0.id != selectedVideoSource.id }
            let showSourceLabels = settings.showSourceLabels

            let gridViewModel = GridViewModel(
                primaryVideoViewModel: VideoRendererViewModel(
                    streamSource: selectedVideoSource,
                    isSelectedVideoSource: true,
                    isSelectedAudioSource: selectedVideoSource.id == selectedAudioSource?.id,
                    showSourceLabel: showSourceLabels,
                    showAudioIndicator: selectedVideoSource.id == selectedAudioSource?.id,
                    videoQuality: .auto
                ),
                secondaryVideoViewModels: secondaryVideoSources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        isSelectedVideoSource: false,
                        isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                        showSourceLabel: showSourceLabels,
                        showAudioIndicator: $0.id == selectedAudioSource?.id,
                        videoQuality: $0.videoQualityList.contains(.low) ? .low : .auto
                    )
                }
            )

            displayMode = .grid(gridViewModel)
        case .single:
            let singleStreamViewModel = SingleStreamViewModel(
                videoViewModels: sortedSources.map {
                    VideoRendererViewModel(
                        streamSource: $0,
                        isSelectedVideoSource: $0.id == selectedVideoSource.id,
                        isSelectedAudioSource: $0.id == selectedAudioSource?.id,
                        showSourceLabel: false,
                        showAudioIndicator: false,
                        videoQuality: .auto
                    )
                },
                selectedVideoSource: selectedVideoSource,
                streamDetail: streamDetail
            )
            displayMode = .single(singleStreamViewModel)
        }

        self.internalState = .success(
            displayMode: displayMode,
            sources: sortedSources,
            selectedVideoSource: selectedVideoSource,
            selectedAudioSource: selectedAudioSource,
            settings: settings
        )
    }

    private func updateStreamSettings(from sources: [StreamSource], settings: StreamSettings) {
        // Only update the settings when the sources change, only sources with at least one audio track
        let sourceIds = sources.filter { $0.audioTracksCount > 0 }.compactMap { $0.sourceId.value }
        if sourceIds != settings.audioSources {
            var updatedSettings = settings
            updatedSettings.audioSources = sourceIds

            // If source selected in settings is no longer available, update the settings
            if case let .source(sourceId) = settings.audioSelection, !settings.audioSources.contains(sourceId) {
                updatedSettings.audioSelection = .firstSource
            }
            
            settingsManager.update(settings: updatedSettings, for: settingsMode)
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
            selectedAudioSource = sourcesWithAudio.first(where: { $0.sourceId == StreamSource.SourceId(id: sourceId) }) ?? sourcesWithAudio[0]
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
            settings: _
        ):
            return currentlySelectedAudioSource
        default:
            return nil
        }
    }
}
