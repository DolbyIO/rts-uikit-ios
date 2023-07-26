//
//  StatisticsInfoView.swift
//

import DolbyIOUIKit
import SwiftUI
import DolbyIORTSCore


struct StatisticsInfoView: View {
    private var viewModel: StatsInfoViewModel
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let fontCaption = Font.custom("AvenirNext-Bold", size: FontSize.caption1)
    private let fontTable = Font.custom("AvenirNext-Regular", size: FontSize.body)
    private let fontTableValue = Font.custom("AvenirNext-Bold", size: FontSize.body)
    private let fontTitle = Font.custom("AvenirNext-Bold", size: FontSize.title2)
    
    init(viewModel: StatsInfoViewModel) {
        self.viewModel = viewModel
    }
    
    private var theme: Theme {
        themeManager.theme
    }

    var body: some View {
        ScrollView {
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray)
                    .frame(width: 48, height: 5)
                    .padding([.top], 5)
                Text("stream.media-stats.label", font: fontTitle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding([.top], 20)
                    .padding([.bottom], 25)

                HStack {
                    Text("stream.stats.name.label", font: fontCaption).frame(width: 170, alignment: .leading)
                    Text("stream.stats.value.label", font: fontCaption).frame(width: 170, alignment: .leading)
                }
                
                ForEach(viewModel.data) { item in
                    HStack {
                        Text(item.key).font(fontTable).foregroundColor(Color(theme.neutral200)).frame(width: 170, alignment: .leading)
                        Text(item.value).font(fontTableValue).foregroundColor(Color(theme.onBackground)).bold().frame(width: 170, alignment: .leading)
                    }
                    .padding([.top], 5)
                }
            }
            .padding([.leading, .trailing], 15)
            .padding([.bottom], 10)
        }
    }
}
