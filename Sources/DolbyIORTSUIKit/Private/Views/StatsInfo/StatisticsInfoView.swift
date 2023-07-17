//
//  StatisticsInfoView.swift
//

import DolbyIOUIKit
import SwiftUI
import DolbyIORTSCore


struct StatisticsInfoView: View {
    @StateObject private var viewModel: StatsInfoViewModel
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private let fontCaption = Font.custom("AvenirNext-Bold", size: FontSize.caption1)
    private let fontTable = Font.custom("AvenirNext-Regular", size: FontSize.caption1)
    private let fontTitle = Font.custom("AvenirNext-Bold", size: FontSize.title2)
    
    init(viewModel: StatsInfoViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                Text("stream.media-stats.label", font: fontCaption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding([.top], 20)
                    .padding([.bottom], 25)

                HStack {
                    Text("stream.stats.name.label", font: fontCaption).frame(width: 170, alignment: .leading)
                    Text("stream.stats.value.label", font: fontCaption).frame(width: 170, alignment: .leading)
                }
                .padding([.leading, .trailing], 15)
                
                ForEach(viewModel.data) { item in
                    HStack {
                        Text(item.key, font: fontTable).frame(width: 170, alignment: .leading)
                        Text(item.value).font(fontTable).frame(width: 170, alignment: .leading)
                    }
                    .padding([.top], 5)
                    .padding([.leading, .trailing], 15)
                }
            }
            .padding([.bottom], 10)
        }
        .frame(maxWidth: 500, maxHeight: 600, alignment: .bottom)
            .background {
                Rectangle().fill(Color(uiColor: ThemeManager.shared.theme.neutral900).opacity(0.7))
                    .ignoresSafeArea(.container, edges: .all)
            }
            .cornerRadius(Layout.cornerRadius14x)
    }
}
