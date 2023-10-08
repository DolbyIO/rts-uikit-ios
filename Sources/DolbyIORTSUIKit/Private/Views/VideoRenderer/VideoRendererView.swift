//
//  VideoRendererView.swift
//

import AVKit
import DolbyIORTSCore
import DolbyIOUIKit
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
    private func showLabel(for source: StreamSource) -> some View {
        if viewModel.showSourceLabel {
            SourceLabel(sourceId: source.sourceId.displayLabel)
                .padding(5)
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
            .allowsHitTesting(true)
            .frame(width: videoSize.width, height: videoSize.height)
            .background(.red)
            .overlay(alignment: .bottomLeading) {
                showLabel(for: viewModel.streamSource)
            }
            .overlay {
                audioPlaybackIndicatorView
            }
//            .onTapGesture {
//                action?(viewModel.streamSource)
//            }
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
        let containerView = VideoRendererPictureInPictureView<UIView>()
        containerView.updateChildView(viewRenderer.playbackView)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let containerView = uiView as? VideoRendererPictureInPictureView<UIView> else {
            return
        }
        containerView.updateChildView(viewRenderer.playbackView)
    }
}


final class VideoRendererPictureInPictureView<ChildView: UIView>: UIView, AVPictureInPictureControllerDelegate {

    private var childView: ChildView?

    private var avplayerLayer: AVPlayerLayer!

    private lazy var pipButton: UIButton = {
        let button = UIButton()
        let startImage = AVPictureInPictureController.pictureInPictureButtonStartImage
        let stopImage = AVPictureInPictureController.pictureInPictureButtonStopImage
        
        button.setImage(startImage, for: .normal)
        button.setImage(stopImage, for: .selected)
        button.addTarget(self, action: #selector(togglePictureInPictureMode(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor.grey50
        return button
    }()
    
    var observation: NSKeyValueObservation?
    var pipPossibleObservation: NSKeyValueObservation?

    var pipController: AVPictureInPictureController!
    
    init() {
        super.init(frame: .zero)

//        setupPictureInPictureUsingThirdPartyFramework()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupPictureInPictureUsingCustomRenderer() {
        if AVPictureInPictureController.isPictureInPictureSupported() {
            guard let childView = childView, pipController == nil else {
                return
            }
            let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
            pipVideoCallViewController.view.addSubview(childView)
            
            let pipContentSource = AVPictureInPictureController.ContentSource(
                activeVideoCallSourceView: childView,
                contentViewController: pipVideoCallViewController
            )
            
            let pipController = AVPictureInPictureController(contentSource: pipContentSource)
            pipController.canStartPictureInPictureAutomaticallyFromInline = true
            pipController.delegate = self
            
            self.pipController = pipController
        } else {
            // PiP isn't supported by the current device. Disable the PiP button.
            pipButton.isEnabled = false
        }
    }
    
    func setupPictureInPictureUsingThirdPartyFramework() {
        avplayerLayer = AVPlayerLayer()
        avplayerLayer.frame = CGRect(x: 0, y: 0, width: 0.1, height: 0.1)

        let mp4Video = Bundle.module.url(forResource: "sample-video", withExtension: "mp4")
        let asset = AVAsset.init(url: mp4Video!)
        let playerItem = AVPlayerItem.init(asset: asset)

        let player = AVPlayer.init(playerItem: playerItem)
        avplayerLayer.player = player
        layer.addSublayer(avplayerLayer)
                
        if AVPictureInPictureController.isPictureInPictureSupported() {
            // Create a new controller, passing the reference to the AVPlayerLayer.
            pipController = AVPictureInPictureController(playerLayer: avplayerLayer)
            
            pipController.delegate = self
        } else {
            // PiP isn't supported by the current device. Disable the PiP button.
            pipButton.isEnabled = false
        }
    }
    
    func updateChildView(_ view: ChildView) {
        childView?.removeFromSuperview()
        pipButton.removeFromSuperview()

        view.translatesAutoresizingMaskIntoConstraints = false

        insertSubview(view, at: 0)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor),
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        childView = view

        addSubview(pipButton)
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            pipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        
        setupPictureInPictureUsingCustomRenderer()
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    @objc func togglePictureInPictureMode(_ sender: UIButton) {
        if pipController.isPictureInPictureActive {
            print("---> stop pip")
            pipController.stopPictureInPicture()
        } else {
            print("---> start pip")
            pipController.startPictureInPicture()
            print("---> suspended state \(pipController.isPictureInPictureSuspended)")
        }
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> will start pip")
        if let window = UIApplication.shared.windows.first {
            let videoView = childView ?? UIView()
            window.addSubview(videoView)
            NSLayoutConstraint.activate([
                window.rootViewController!.view.topAnchor.constraint(equalTo: videoView.topAnchor),
                window.rootViewController!.view.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
                videoView.bottomAnchor.constraint(equalTo: window.rootViewController!.view.bottomAnchor),
                videoView.trailingAnchor.constraint(equalTo: window.rootViewController!.view.trailingAnchor)
            ])
        }
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> did start pip")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> did stop pip")
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("---> failedToStartPictureInPictureWithError - \(error.localizedDescription)")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        print("---> restoreUserInterfaceForPictureInPictureStopWithCompletionHandler")
        completionHandler(true)
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> will stop pip")
    }
}
