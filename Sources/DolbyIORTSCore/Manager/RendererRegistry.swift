//
//  RendererRegistry.swift
//

import Foundation
import MillicastSDK
import os

protocol RendererRegistryProtocol: AnyObject {
    func registerRenderer(_ renderer: StreamSourceViewRenderer, for track: MCVideoTrack) async
    func deregisterRenderer(_ renderer: StreamSourceViewRenderer, for track: MCVideoTrack) async

    func hasActiveRenderer(for track: MCVideoTrack) async -> Bool

    func reset() async
}

final actor RendererRegistry: RendererRegistryProtocol {
    private static let logger = Logger(subsystem: "io.dolby.rtscore", category: String(describing: RendererRegistry.self))

    private var rendererDictionary: [String: NSHashTable<StreamSourceViewRenderer>] = [:]

    func registerRenderer(_ renderer: StreamSourceViewRenderer, for track: MCVideoTrack) {
        guard let trackID = track.getId() else {
            Self.logger.error("📺 Register renderer \(renderer.id) called with an invalid VideoTrack")
            return
        }

        if let renderers = rendererDictionary[trackID] {
            guard !renderers.contains(renderer) else {
                return
            }
            renderers.add(renderer)
        } else {
            let renderers = NSHashTable<StreamSourceViewRenderer>(options: .weakMemory)
            renderers.add(renderer)
            rendererDictionary[trackID] = renderers
        }
    }

    func deregisterRenderer(_ renderer: StreamSourceViewRenderer, for track: MCVideoTrack) {
        guard let trackID = track.getId() else {
            Self.logger.error("📺 Deregister renderer \(renderer.id) called with an invalid VideoTrack")
            return
        }

        if let renderers = rendererDictionary[trackID] {
            renderers.remove(renderer)
        }
    }

    func hasActiveRenderer(for track: MCVideoTrack) -> Bool {
        guard
            let trackID = track.getId(),
            let renderers = rendererDictionary[trackID]
        else {
            return false
        }

        return renderers.count != 0
    }

    func reset() {
        rendererDictionary.removeAll()
    }
}
