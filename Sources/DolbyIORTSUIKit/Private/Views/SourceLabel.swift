//
//  SourceLabel.swift
//

import SwiftUI
import DolbyIOUIKit

struct SourceLabel: View {

    public let sourceId: String

    @ObservedObject private var themeManager = ThemeManager.instance

    var body: some View {
        SwiftUI.Text(sourceId)
            .foregroundColor(.white)
            .font(.custom("AvenirNext-Regular", size: FontSize.caption1, relativeTo: .body))
            .padding(.horizontal, Layout.spacing1x)
            .background(Color(uiColor: themeManager.theme.neutral400))
            .cornerRadius(Layout.cornerRadius4x)
    }
}

struct SourceLabel_Previews: PreviewProvider {
    static var previews: some View {
        SourceLabel(sourceId: "Camera 01")
    }
}
