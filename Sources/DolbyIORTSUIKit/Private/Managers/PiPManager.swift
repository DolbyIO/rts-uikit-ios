//
//  PiPManager.swift
//

import AVFoundation
import AVKit
import Foundation
import MillicastSDK
import UIKit

final class PiPManager: NSObject {
    static let shared: PiPManager = PiPManager()
    
    enum Constants {
        static let defaultVideoTileSize = CGSize(width: 533, height: 300)
    }
    
    private override init() {}
    
    private var pipController: AVPictureInPictureController?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    
    func set(pipView: MCSampleBufferVideoUIView, with targetView: UIView) {
        pipController?.stopPictureInPicture()
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("---> isPictureInPictureSupported false")
            return
        }

        let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
        pipVideoCallViewController.view.addSubview(pipView)
        pipView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pipVideoCallViewController.view.topAnchor.constraint(equalTo: pipView.topAnchor),
            pipVideoCallViewController.view.leadingAnchor.constraint(equalTo: pipView.leadingAnchor),
            pipView.bottomAnchor.constraint(equalTo: pipVideoCallViewController.view.bottomAnchor),
            pipView.trailingAnchor.constraint(equalTo: pipVideoCallViewController.view.trailingAnchor)
        ])
        pipVideoCallViewController.preferredContentSize = targetView.frame.size
        
        let pipContentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: targetView,
            contentViewController: pipVideoCallViewController
        )
        
        let pipController = AVPictureInPictureController(contentSource: pipContentSource)
        pipController.canStartPictureInPictureAutomaticallyFromInline = true
        pipController.delegate = self
        
        NotificationCenter.default
            .addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.stopPiP()
            }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            self.pipController = pipController
        } catch {
            print("---> AVAudioSession.setActive failed \(error.localizedDescription)")
        }
    }
    
    func stopPiP() {
        pipController?.stopPictureInPicture()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> pictureInPictureControllerDidStartPictureInPicture")
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("---> pictureInPictureControllerDidStopPictureInPicture")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("---> pictureInPictureController:failedToStartPictureInPictureWithError: \(error.localizedDescription)")
    }
}
