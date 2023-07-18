//
//  StreamingScreen.swift
//

import SwiftUI
import DolbyIORTSCore
import DolbyIOUIKit

public struct StreamingScreen: View {
    @StateObject private var viewModel: StreamViewModel = .init()
    @Binding private var isShowingStreamView: Bool
    @State private var isShowingSingleViewScreen: Bool = false
    @State private var isShowingSettingsScreen: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var theme: Theme { themeManager.theme }
    
    public init(isShowingStreamView: Binding<Bool>) {
        _isShowingStreamView = isShowingStreamView
    }

    @ViewBuilder
    private var singleStreamDetailView: some View {
        if let singleStreamUiState = viewModel.detailSingleStreamViewModel {
            SingleStreamView(
                viewModel: viewModel,
                uiState: singleStreamUiState,
                isShowingDetailPresentation: true,
                onSelect: {
                    viewModel.selectVideoSource($0)
                },
                onClose: {
                    isShowingSingleViewScreen = false
                }
            )
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func streamView(for displayMode: StreamViewModel.DisplayMode) -> some View {
        ZStack {
            switch displayMode {
            case let .list(listViewModel):
                ListView(
                    viewModel: listViewModel,
                    onPrimaryVideoSelection: { _ in
                        isShowingSingleViewScreen = true
                    },
                    onSecondaryVideoSelection: {
                        viewModel.selectVideoSource($0)
                    }
                )
            case let .single(singleStreamUiState):
                SingleStreamView(
                    viewModel: viewModel,
                    uiState: singleStreamUiState,
                    isShowingDetailPresentation: false,
                    onSelect: {
                        viewModel.selectVideoSource($0)
                    }
                )
            case let .grid(gridViewModel):
                GridView(
                    viewModel: gridViewModel,
                    onVideoSelection: {
                        viewModel.selectVideoSource($0)
                        isShowingSingleViewScreen = true
                    }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            liveIndicatorView
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                IconButton(iconAsset: .close) {
                    endStream()
                }
            }
            ToolbarItem(placement: .principal) {
                let streamName = viewModel.streamDetail.streamName
                Text(
                    verbatim: streamName,
                    font: .custom("AvenirNext-Regular", size: FontSize.subhead, relativeTo: .subheadline)
                )
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                SettingsButton { isShowingSettingsScreen = true }
            }
        }
    }
    
    @ViewBuilder
    private func errorView(for viewModel: ErrorViewModel) -> some View {
        ErrorView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                closeButton
            }
            .overlay(alignment: .topLeading) {
                liveIndicatorView
            }
    }
    
    @ViewBuilder
    private var closeButton: some View {
        IconButton(iconAsset: .close) {
            endStream()
        }
        .background(Color(uiColor: theme.neutral400))
        .clipShape(Circle().inset(by: Layout.spacing0_5x))
    }
    
    @ViewBuilder
    private var progressView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var liveIndicatorView: some View {
        let shouldShowLiveIndicatorView: Bool = {
            switch viewModel.state {
            case let .success(displayMode: displayMode):
                switch displayMode {
                case .list: return true
                case .grid: return true
                case .single: return false
                }
            default: return true
            }
        }()
        if shouldShowLiveIndicatorView {
            LiveIndicatorView()
                .padding(Layout.spacing0_5x)
        } else {
            EmptyView()
        }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                NavigationLink(
                    destination: LazyNavigationDestinationView(
                        singleStreamDetailView
                    ),
                    isActive: $isShowingSingleViewScreen
                ) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(
                    destination: LazyNavigationDestinationView(
                        SettingsScreen(mode: viewModel.settingsMode)
                    ),
                    isActive: $isShowingSettingsScreen
                ) {
                    EmptyView()
                }.hidden()

                switch viewModel.state {
                case let .success(displayMode: displayMode):
                    streamView(for: displayMode)
                case .loading:
                    progressView
                case let .error(errorViewModel):
                    errorView(for: errorViewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: Helper functions

extension StreamingScreen {
    func endStream() {
        _isShowingStreamView.wrappedValue = false
        Task {
            await viewModel.endStream()
        }
    }
}
