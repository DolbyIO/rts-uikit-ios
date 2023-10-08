//
//  StreamSourceViewProvider.swift
//

import Foundation
import MillicastSDK
import UIKit

public class StreamSourceViewRenderer: Identifiable {

    enum Constants {
        static let defaultVideoTileSize = CGSize(width: 533, height: 300)
    }

    private let renderer: MCPIPVideoRenderer
    
    let videoTrack: MCVideoTrack

    public let id = UUID()

    public init(_ streamSource: StreamSource) {
        let videoTrack = streamSource.videoTrack.track
        self.renderer = MCPIPVideoRenderer()
        self.videoTrack = videoTrack

        Task {
            await MainActor.run {
                videoTrack.add(renderer)
            }
        }
    }

    public var frameWidth: CGFloat {
        hasValidDimensions ? CGFloat(renderer.getWidth()) : Constants.defaultVideoTileSize.width
    }

    public var frameHeight: CGFloat {
        hasValidDimensions ? CGFloat(renderer.getHeight()) : Constants.defaultVideoTileSize.height
    }

    public var playbackView: UIView {
        renderer
    }
}

// MARK: Helper functions

private extension StreamSourceViewRenderer {
    
    var hasValidDimensions: Bool {
        renderer.getWidth() != 0 && renderer.getHeight() != 0
    }
}
