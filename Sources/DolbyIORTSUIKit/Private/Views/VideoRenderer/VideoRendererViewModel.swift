//
//  VideoRendererViewModel.swift
//

import DolbyIORTSCore
import Foundation

enum VideoRendererContentMode {
    case aspectFit, aspectFill, scaleToFill
}

final class VideoRendererViewModel: ObservableObject {

    private let streamOrchestrator: StreamOrchestrator
    let isSelectedVideoSource: Bool
    let isSelectedAudioSource: Bool
    let streamSource: StreamSource
    let showSourceLabel: Bool
    let showAudioIndicator: Bool
    @Published var videoQuality: VideoQuality

    init(
        streamSource: StreamSource,
        isSelectedVideoSource: Bool,
        isSelectedAudioSource: Bool,
        showSourceLabel: Bool,
        showAudioIndicator: Bool,
        videoQuality: VideoQuality,
        streamOrchestrator: StreamOrchestrator = .shared
    ) {
        self.streamSource = streamSource
        self.isSelectedVideoSource = isSelectedVideoSource
        self.isSelectedAudioSource = isSelectedAudioSource
        self.showSourceLabel = showSourceLabel
        self.showAudioIndicator = showAudioIndicator
        self.videoQuality = videoQuality
        self.streamOrchestrator = streamOrchestrator
    }
    
    func playVideo(on viewRenderer: StreamSourceViewRenderer, quality: VideoQuality? = nil) {
        Task { @StreamOrchestrator in
            await self.streamOrchestrator.playVideo(
                for: streamSource,
                on: viewRenderer,
                with: quality ?? videoQuality
            )
        }
    }

    func stopVideo(on viewRenderer: StreamSourceViewRenderer) {
        Task { @StreamOrchestrator in
            await self.streamOrchestrator.stopVideo(
                for: streamSource,
                on: viewRenderer
            )
        }
    }
}
