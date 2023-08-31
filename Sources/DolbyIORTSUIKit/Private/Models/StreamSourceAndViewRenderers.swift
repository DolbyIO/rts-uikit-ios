//
//  StreamSourceAndViewRenderers.swift
//

import DolbyIORTSCore
import Foundation

final class ViewRendererProvider: ObservableObject {
    private var rendererDictionary: [UUID: StreamSourceViewRenderer] = [:]

    func renderer(for source: StreamSource) -> StreamSourceViewRenderer {
        if let renderer = rendererDictionary[source.id] {
            return renderer
        } else {
            let renderer = StreamSourceViewRenderer(source)
            rendererDictionary[source.id] = renderer
            return renderer
        }
    }
}
