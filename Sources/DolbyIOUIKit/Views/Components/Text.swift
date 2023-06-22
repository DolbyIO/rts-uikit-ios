//
//  Text.swift
//  

import SwiftUI

public struct Text: View {

    private let text: LocalizedStringKey
    private let bundle: Bundle?
    private let style: TextStyles
    private let font: Font
    private let textColor: Color?

    @ObservedObject private var themeManager = ThemeManager.shared

    public init(
        text: LocalizedStringKey,
        bundle: Bundle? = nil,
        style: TextStyles = .labelMedium,
        font: Font,
        textColor: Color? = nil
    ) {
        self.text = text
        self.bundle = bundle
        self.style = style
        self.font = font
        self.textColor = textColor
    }

    private var attribute: TextAttribute {
        themeManager.theme.textAttribute(for: style)
    }

    public var body: some View {
        SwiftUI.Text(text, bundle: bundle)
            .foregroundColor(_textColor)
            .font(font)
    }
}

// MARK: Private helper functions

private extension Text {
    var _textColor: Color? {
        if let textColor = textColor {
            return textColor
        }

        return attribute.textColor
    }
}

#if DEBUG
struct Text_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                Text(
                    text: "testA.localized.key",
                    bundle: .module,
                    style: .titleMedium,
                    font: .custom("AvenirNext-Regular", size: FontSize.title1, relativeTo: .title)
                )

                Text(
                    text: "This is a regular text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Regular", size: FontSize.title1, relativeTo: .title)
                )

                Text(
                    text: "This is a regular text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Regular", size: FontSize.title2, relativeTo: .title2)
                )

                Text(
                    text: "This is a regular text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Regular", size: FontSize.title3, relativeTo: .title3)
                )
            }

            VStack {
                Text(
                    text: "This is a bold text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Bold", size: FontSize.title1, relativeTo: .title)
                )

                Text(
                    text: "This is a bold text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Bold", size: FontSize.title2, relativeTo: .title2)
                )

                Text(
                    text: "This is a bold text",
                    style: .titleMedium,
                    font: .custom("AvenirNext-Bold", size: FontSize.title1, relativeTo: .title3)
                )
            }
        }
    }
}
#endif
