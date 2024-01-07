//
//  VideoRendererView.swift
//

import DolbyIORTSCore
import DolbyIOUIKit
import MillicastSDK
import SwiftUI

struct VideoRendererView: View {
    @ObservedObject private var viewModel: VideoRendererViewModel
    private let viewRenderer: StreamSourceViewRenderer
    private let maxWidth: CGFloat
    private let maxHeight: CGFloat
    private let contentMode: VideoRendererContentMode
    private let action: ((StreamSource) -> Void)?
    @State var isViewVisible = false

    @ObservedObject private var themeManager = ThemeManager.shared
    @AppConfiguration(\.showDebugFeatures) var showDebugFeatures

    init(
        viewModel: VideoRendererViewModel,
        viewRenderer: StreamSourceViewRenderer,
        maxWidth: CGFloat,
        maxHeight: CGFloat,
        contentMode: VideoRendererContentMode,
        action: ((StreamSource) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.viewRenderer = viewRenderer
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.contentMode = contentMode
        self.action = action
    }

    private var theme: Theme {
        themeManager.theme
    }

    @ViewBuilder
    private var audioPlaybackIndicatorView: some View {
        if viewModel.showAudioIndicator {
            Rectangle()
                .stroke(
                    Color(uiColor: theme.primary400),
                    lineWidth: Layout.border2x
                )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var sourceLabelView: some View {
        if viewModel.showSourceLabel {
            SourceLabel(sourceId: viewModel.streamSource.sourceId.displayLabel)
                .padding(Layout.spacing0_5x)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var videoQualityIndicatorView: some View {
        if showDebugFeatures, let videoQualityIndicatorText = viewModel.videoQuality.description.first?.uppercased() {
            Text(
                verbatim: videoQualityIndicatorText,
                font: .custom("AvenirNext-Regular", size: FontSize.caption1, relativeTo: .caption)
            )
            .foregroundColor(Color(uiColor: themeManager.theme.onPrimary))
            .padding(.horizontal, Layout.spacing1x)
            .background(Color(uiColor: themeManager.theme.neutral400))
            .cornerRadius(Layout.cornerRadius4x)
            .padding(Layout.spacing0_5x)
        } else {
            EmptyView()
        }
    }

    var body: some View {
        let videoSize: CGSize = {
            switch contentMode {
            case .aspectFit:
                return viewRenderer.videoViewDisplaySize(
                    forAvailableScreenWidth: maxWidth,
                    availableScreenHeight: maxHeight,
                    shouldCrop: false
                )
            case .aspectFill:
                return viewRenderer.videoViewDisplaySize(
                    forAvailableScreenWidth: maxWidth,
                    availableScreenHeight: maxHeight,
                    shouldCrop: true
                )
            case .scaleToFill:
                return CGSize(width: maxWidth, height: maxHeight)
            }
        }()

        VideoRendererViewInternal(viewRenderer: viewRenderer)
            .frame(width: videoSize.width, height: videoSize.height)
            .overlay(alignment: .bottomLeading) {
                sourceLabelView
            }
            .overlay(alignment: .bottomTrailing) {
                videoQualityIndicatorView
            }
            .overlay {
                audioPlaybackIndicatorView
            }
            .onTapGesture {
                action?(viewModel.streamSource)
            }
            .onAppear {
                isViewVisible = true
                viewModel.playVideo(on: viewRenderer)
            }
            .onDisappear {
                isViewVisible = false
                viewModel.stopVideo(on: viewRenderer)
            }
            .onChange(of: viewModel.videoQuality) { newValue in
                guard isViewVisible else { return }
                viewModel.playVideo(on: viewRenderer, quality: newValue)
            }
    }
}

private struct VideoRendererViewInternal: UIViewRepresentable {
    private let viewRenderer: StreamSourceViewRenderer

    init(viewRenderer: StreamSourceViewRenderer) {
        self.viewRenderer = viewRenderer
    }

    func makeUIView(context: Context) -> UIView {
        viewRenderer.playbackView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
