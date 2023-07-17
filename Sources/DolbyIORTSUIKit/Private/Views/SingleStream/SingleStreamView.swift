//
//  SingleStreamView.swift
//

import SwiftUI
import DolbyIORTSCore
import DolbyIOUIKit

struct SingleStreamView: View {

    private enum Animation {
        static let duration: CGFloat = 0.75
        static let blendDuration: CGFloat = 3.0
        static let offset: CGFloat = 200.0
    }

    private let viewModel: SingleStreamViewModel
    private let isShowingDetailPresentation: Bool
    private let onSelect: ((StreamSource) -> Void)
    private let onClose: (() -> Void)?

    @State private var showScreenControls = false
    @State private var selectedVideoStreamSourceId: UUID
    @State private var isShowingSettingsScreen: Bool = false
    @State private var isShowingStatsInfoScreen: Bool = false
    @StateObject private var userInteractionViewModel: UserInteractionViewModel = .init()

    @ObservedObject private var themeManager = ThemeManager.shared

    init(
        viewModel: SingleStreamViewModel,
        isShowingDetailPresentation: Bool,
        onSelect: @escaping (StreamSource) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.isShowingDetailPresentation = isShowingDetailPresentation
        self.onSelect = onSelect
        self.onClose = onClose
        _selectedVideoStreamSourceId = State(wrappedValue: viewModel.selectedVideoSource.id)
    }

    private var theme: Theme {
        themeManager.theme
    }

    @ViewBuilder
    private var topToolBarView: some View {
        HStack {
            LiveIndicatorView()
            Spacer()
            if isShowingDetailPresentation {
                closeButton
            }
        }
        .ignoresSafeArea()
        .padding(Layout.spacing1x)
    }

    @ViewBuilder
    private var bottomToolBarView: some View {
        HStack {
            StatsInfoButton { isShowingStatsInfoScreen.toggle() }
                .gesture(
                    DragGesture()
                        .onChanged { _ in
                            withAnimation {
                                isShowingStatsInfoScreen = false
                            }
                        }
                )

            Spacer()

            if isShowingDetailPresentation {
                SettingsButton { isShowingSettingsScreen = true }
            }
        }
        .ignoresSafeArea()
        .padding(Layout.spacing1x)
    }

    @ViewBuilder
    private var closeButton: some View {
        IconButton(iconAsset: .close) {
            onClose?()
        }
        .background(Color(uiColor: theme.neutral400))
        .clipShape(Circle().inset(by: Layout.spacing0_5x))
    }

    var body: some View {
        ZStack {
            NavigationLink(
                destination: LazyNavigationDestinationView(
                    SettingsScreen(mode: viewModel.settingsMode)
                ),
                isActive: $isShowingSettingsScreen
            ) {
                EmptyView()
            }.hidden()

            GeometryReader { proxy in
                TabView(selection: $selectedVideoStreamSourceId) {
                    ForEach(viewModel.videoViewModels, id: \.streamSource.id) { viewModel in
                        let maxAllowedVideoWidth = proxy.size.width
                        let maxAllowedVideoHeight = proxy.size.height

                        HStack {
                            VideoRendererView(
                                viewModel: viewModel,
                                maxWidth: maxAllowedVideoWidth,
                                maxHeight: maxAllowedVideoHeight,
                                contentMode: .aspectFit
                            )
                        }
                        .tag(viewModel.streamSource.id)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .overlay(alignment: .top) {
                    topToolBarView
                        .offset(x: 0, y: showScreenControls ? 0 : -Animation.offset)
                }
                .overlay(alignment: .bottom) {
                    bottomToolBarView
                        .offset(x: 0, y: showScreenControls ? 0 : Animation.offset)
                }
                .onAppear {
                    showControlsAndObserveInteractions()
                }
                .onReceive(userInteractionViewModel.interactivityTimer) { _ in
                    guard isShowingDetailPresentation else {
                        return
                    }
                    hideControlsAndStopObservingInteractions()
                }
                .onTapGesture {
                    guard isShowingDetailPresentation else {
                        return
                    }
                    if showScreenControls {
                        hideControlsAndStopObservingInteractions()
                    } else {
                        showControlsAndObserveInteractions()
                    }
                }
                .onChange(of: selectedVideoStreamSourceId) { newValue in
                    guard let selectedStreamSource = viewModel.streamSource(for: newValue) else {
                        return
                    }
                    onSelect(selectedStreamSource)
                }
            }
            .navigationBarHidden(isShowingDetailPresentation)
            
            if isShowingStatsInfoScreen {
                HStack {
                    StatisticsInfoView(viewModel: StatsInfoViewModel(streamSource: viewModel.selectedVideoSource))
                    
                    Spacer()
                }
                .frame(alignment: Alignment.bottom)
                .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func showControlsAndObserveInteractions() {
        withAnimation(.spring(blendDuration: Animation.blendDuration)) {
            showScreenControls = true
        }
        guard isShowingDetailPresentation else {
            return
        }
        userInteractionViewModel.startInteractivityTimer()
    }

    private func hideControlsAndStopObservingInteractions() {
        withAnimation(.easeOut(duration: Animation.duration)) {
            showScreenControls = false
        }
        userInteractionViewModel.stopInteractivityTimer()
    }
}

struct Handle : View {
    private let handleThickness = CGFloat(5.0)
    var body: some View {
        RoundedRectangle(cornerRadius: handleThickness / 2.0)
            .frame(width: 40, height: handleThickness)
            .foregroundColor(Color.secondary)
            .padding(5)
    }
}

struct SlideOverCard<Content: View> : View {
    @GestureState private var dragState = DragState.inactive
    @State var position = CardPosition.top
    
    var content: () -> Content
    var body: some View {
        let drag = DragGesture()
            .updating($dragState) { drag, state, transaction in
                state = .dragging(translation: drag.translation)
            }
            .onEnded(onDragEnded)
        
        return Group {
            Handle()
            self.content()
        }
        .frame(height: UIScreen.main.bounds.height)
        .background(Color.white)
        .cornerRadius(10.0)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.13), radius: 10.0)
        .offset(y: self.position.rawValue + self.dragState.translation.height)
        .animation(self.dragState.isDragging ? nil : .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0))
        .gesture(drag)
    }
    
    private func onDragEnded(drag: DragGesture.Value) {
        let verticalDirection = drag.predictedEndLocation.y - drag.location.y
        let cardTopEdgeLocation = self.position.rawValue + drag.translation.height
        let positionAbove: CardPosition
        let positionBelow: CardPosition
        let closestPosition: CardPosition
        
        if cardTopEdgeLocation <= CardPosition.middle.rawValue {
            positionAbove = .top
            positionBelow = .middle
        } else {
            positionAbove = .middle
            positionBelow = .bottom
        }
        
        if (cardTopEdgeLocation - positionAbove.rawValue) < (positionBelow.rawValue - cardTopEdgeLocation) {
            closestPosition = positionAbove
        } else {
            closestPosition = positionBelow
        }
        
        if verticalDirection > 0 {
            self.position = positionBelow
        } else if verticalDirection < 0 {
            self.position = positionAbove
        } else {
            self.position = closestPosition
        }
    }
}

enum CardPosition: CGFloat {
    case top = 100
    case middle = 500
    case bottom = 850
}

enum DragState {
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    var isDragging: Bool {
        switch self {
        case .inactive:
            return false
        case .dragging:
            return true
        }
    }
}
