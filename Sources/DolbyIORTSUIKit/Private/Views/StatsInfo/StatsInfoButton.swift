//
//  StatsInfoButton.swift
//

import DolbyIORTSCore
import DolbyIOUIKit
import SwiftUI

struct StatsInfoButton: View {

    @StateObject private var viewModel: StatsInfoViewModel

    init(streamSource: StreamSource) {
        _viewModel = StateObject(wrappedValue: StatsInfoViewModel(streamSource: streamSource))
    }

    var body: some View {
        IconButton(
            iconAsset: .info
        ) {
            // TODO: Handle as part of status info screen ticket
        }
    }
}
