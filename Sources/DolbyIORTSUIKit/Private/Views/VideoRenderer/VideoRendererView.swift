//
//  VideoRendererView.swift
//

import AVKit
import DolbyIORTSCore
import DolbyIOUIKit
import SwiftUI

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    init(_ session: AVCaptureSession) {
        super.init(frame: .zero)
        
        previewLayer.session = session
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

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

        VideoRendererViewInternal(
            viewRenderer: viewRenderer,
            videoSize: videoSize,
            isSelectedVideoSource: viewModel.isSelectedVideoSource
        )
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
    private let videoSize: CGSize
    private let isSelectedVideoSource: Bool

    init(viewRenderer: StreamSourceViewRenderer, videoSize: CGSize, isSelectedVideoSource: Bool) {
        self.viewRenderer = viewRenderer
        self.videoSize = videoSize
        self.isSelectedVideoSource = isSelectedVideoSource
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = VideoRendererPictureInPictureView<UIView>()
        containerView.updateChildView(
            viewRenderer.playbackView,
            pipPlaybackView: viewRenderer.pipPlaybackView,
            videoSize: self.videoSize,
            isSelectedVideoSource: isSelectedVideoSource
        )
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let containerView = uiView as? VideoRendererPictureInPictureView<UIView> else {
            return
        }
        containerView.updateChildView(
            viewRenderer.playbackView,
            pipPlaybackView: viewRenderer.pipPlaybackView,
            videoSize: self.videoSize,
            isSelectedVideoSource: isSelectedVideoSource
        )
    }
}


final class VideoRendererPictureInPictureView<ChildView: UIView>: UIView {

    private var childView: ChildView?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    
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
    
    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let captureSession = AVCaptureSession()
    let captureSessionQueue = DispatchQueue(label: "Capture Session Queue")

    func setupPictureInPictureUsingCustomRenderer(with view: UIView, for videoSize: CGSize) {
        if AVPictureInPictureController.isPictureInPictureSupported() {
            if pipVideoCallViewController == nil, let currentLayer = view.layer as? AVSampleBufferDisplayLayer {
                let pipVideoCallViewController = AVPictureInPictureVideoCallViewController(view, preferredContentSize: videoSize)
                
//                let previewView = PreviewView(captureSession)
//                let pipVideoCallViewController = AVPictureInPictureVideoCallViewController(previewView, preferredContentSize: videoSize)
//                captureSessionQueue.async { [unowned self] in
//                    let device = AVCaptureDevice.default(for: .video)!
//
//                    captureSession.addInput(try! AVCaptureDeviceInput(device: device))
//                    captureSession.sessionPreset = .hd1920x1080
//                    if #available(iOS 16.0, *) {
//                        captureSession.isMultitaskingCameraAccessEnabled = captureSession.isMultitaskingCameraAccessSupported
//                    } else {
//                        // Fallback on earlier versions
//                    }
//                    captureSession.startRunning()
//                }
                
//                PictureInPictureWrapped.shared.updatePictureInPictureVideoCallViewController(pipVideoCallViewController, targetView: self)
                PictureInPictureWrapped.shared.updatePictureInPictureVideoCallViewController(pipVideoCallViewController, layer: currentLayer)

                self.pipVideoCallViewController = pipVideoCallViewController
                
            }
        }
    }
    
    func updateChildView(_ view: ChildView, pipPlaybackView: UIView, videoSize: CGSize, isSelectedVideoSource: Bool) {
        childView?.removeFromSuperview()
        
        pipPlaybackView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(pipPlaybackView, at: 0)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: pipPlaybackView.topAnchor),
            leadingAnchor.constraint(equalTo: pipPlaybackView.leadingAnchor),
            pipPlaybackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pipPlaybackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        if !self.subviews.contains(pipButton) && isSelectedVideoSource {
            addSubview(pipButton)
            pipButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
                pipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
            ])
        }
        
        if isSelectedVideoSource {
            setupPictureInPictureUsingCustomRenderer(with: pipPlaybackView, for: videoSize)
        } else {
            self.pipButton.removeFromSuperview()
        }
        
        childView = view

        setNeedsLayout()
        layoutIfNeeded()
    }
    
    @objc func togglePictureInPictureMode(_ sender: UIButton) {
        if PictureInPictureWrapped.shared.isPictureInPictureActive {
            print("---> stop pip")
            PictureInPictureWrapped.shared.stopPictureInPicture()
        } else {
            print("---> start pip")
            PictureInPictureWrapped.shared.startPictureInPicture()
        }
    }
}

fileprivate class PictureInPictureWrapped: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    static var shared = PictureInPictureWrapped()
    
    private var pictureInPictureController: AVPictureInPictureController?
    
    var isPictureInPictureActive: Bool {
        guard let pictureInPictureController = pictureInPictureController else {
            return false
        }
        
        return pictureInPictureController.isPictureInPictureActive
    }
    
    func updatePictureInPictureVideoCallViewController(_ videoCallViewController: AVPictureInPictureVideoCallViewController, layer: AVSampleBufferDisplayLayer) {
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: layer,
            playbackDelegate: self
        )
        
//        if let pictureInPictureController = pictureInPictureController {
//            pictureInPictureController.contentSource = contentSource
//        } else {
        try! AVAudioSession.sharedInstance().setActive(true)
            let pictureInPictureController = AVPictureInPictureController(contentSource: contentSource)
            pictureInPictureController.delegate = self

            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true
            self.pictureInPictureController = pictureInPictureController
//        }
    }
    
    
    func updatePictureInPictureVideoCallViewController(_ videoCallViewController: AVPictureInPictureVideoCallViewController, targetView: UIView) {
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: targetView,
            contentViewController: videoCallViewController
        )
        
//        if let pictureInPictureController = pictureInPictureController {
//            pictureInPictureController.contentSource = contentSource
//        } else {
        try! AVAudioSession.sharedInstance().setActive(true)
            let pictureInPictureController = AVPictureInPictureController(contentSource: contentSource)
            pictureInPictureController.delegate = self

            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true
            self.pictureInPictureController = pictureInPictureController
//        }
    }
    
    func startPictureInPicture() {
        guard 
            !isPictureInPictureActive,
            let pipController = pictureInPictureController
        else {
            return
        }
        pipController.startPictureInPicture()
    }
    
    func stopPictureInPicture() {
        guard
            isPictureInPictureActive,
            let pipController = pictureInPictureController
        else {
            return
        }
        pipController.stopPictureInPicture()
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> will start pip")
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
        //completionHandler(true)
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> will stop pip")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        
    }
}

extension AVPictureInPictureVideoCallViewController {
    
    convenience init(_ videoView: UIView, preferredContentSize: CGSize) {
        
        // Initialize.
        self.init()
        
        // Set the preferredContentSize.
        self.preferredContentSize = preferredContentSize
        
        // Configure the PreviewView.
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.frame = self.view.frame
        
        self.view.addSubview(videoView)
        
        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: self.view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
}
