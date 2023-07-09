//
//  GridViewModel.swift
//  
//

import DolbyIORTSCore

final class GridViewModel {
    
    var allVideoViewModels: [VideoRendererViewModel]

    init(primaryVideoViewModel: VideoRendererViewModel, secondaryVideoViewModels: [VideoRendererViewModel]) {
        self.allVideoViewModels = [primaryVideoViewModel]
        self.allVideoViewModels.append(contentsOf: secondaryVideoViewModels)
    }
}
