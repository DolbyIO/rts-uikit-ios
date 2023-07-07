//
//  StatsInfoViewModel.swift
//

import Combine
import DolbyIORTSCore
import Foundation

final class StatsInfoViewModel: ObservableObject {
    let streamSource: StreamSource

    init(streamSource: StreamSource) {
        self.streamSource = streamSource
    }
}
