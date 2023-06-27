//
//  VideoRendererViewModel.swift
//

import DolbyIORTSCore
import Foundation

enum VideoRendererContentMode {
    case aspectFit, aspectFill, scaleToFill
}

final class VideoRendererViewModel {

    private let streamOrchestrator: StreamOrchestrator
    let isSelectedVideoSource: Bool
    let isSelectedAudioSource: Bool
    let streamSource: StreamSource
    let viewRenderer: StreamSourceViewRenderer
    let showSourceLabel: Bool
    let showAudioIndicator: Bool

    init(
        streamSource: StreamSource,
        viewRenderer: StreamSourceViewRenderer,
        isSelectedVideoSource: Bool,
        isSelectedAudioSource: Bool,
        showSourceLabel: Bool,
        showAudioIndicator: Bool,
        streamOrchestrator: StreamOrchestrator = .shared
    ) {
        self.streamSource = streamSource
        self.viewRenderer = viewRenderer
        self.isSelectedVideoSource = isSelectedVideoSource
        self.isSelectedAudioSource = isSelectedAudioSource
        self.showSourceLabel = showSourceLabel
        self.showAudioIndicator = showAudioIndicator
        self.streamOrchestrator = streamOrchestrator
    }

    func playVideo(for source: StreamSource) {
        Task {
            await self.streamOrchestrator.playVideo(for: source, on: viewRenderer, quality: .auto)
        }
    }

    func stopVideo(for source: StreamSource) {
        Task {
            await self.streamOrchestrator.stopVideo(for: source, on: viewRenderer)
        }
    }
}
