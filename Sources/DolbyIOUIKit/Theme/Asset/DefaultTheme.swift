//
//  DefaultTheme.swift
//

import Foundation
import SwiftUI
import UIKit

// swiftlint:disable cyclomatic_complexity
public class DefaultTheme: Theme {

    private lazy var _textFieldAttribute: TextFieldAttribute = textFieldAttributeValue()
    private lazy var _primaryTextAttribute: TextAttribute = primaryTextAttribute()
    private lazy var _secondaryTextAttribute: TextAttribute = secondaryTextAttribute()
    private lazy var _tertiaryTextAttribute: TextAttribute = tertiaryTextAttribute()

    private lazy var _toggleAttribute: ToggleAttribute = toggleAttributeValue()

    private lazy var _iconAttribute: IconAttribute = iconAttributeValue()

    // TODO: map to the right color of theme and use it for component attributes so that component attributes will not be required to be exposed in the theme.
    public let primary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let primaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onPrimary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onPrimaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let inversePrimary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let secondary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let secondaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onSecondary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onSecondaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let tertiary = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let tertiaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onTertiaryContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surface = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceDim = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceBright = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceContainerLowest = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceContainerLow = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceContainerHigh = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceContainerHighest = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceVariant = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onSurface = Color(uiColor: UIColor(light: UIColor.Dolby.grey250, dark: UIColor.Dolby.grey250))
    public let onSurfaceVariant = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let inverseSurface = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let inverseOnSurface = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let background = Color(uiColor: UIColor(light: UIColor.Dolby.black, dark: UIColor.Dolby.black))
    public let onBackground = Color(uiColor: UIColor(light: UIColor.Dolby.white, dark: UIColor.Dolby.white))
    public let error = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let errorContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onError = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let onErrorContainer = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let outline = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let outlineVariant = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let shadow = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let surfaceTint = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
    public let scrim = Color(uiColor: UIColor(light: UIColor.Dolby.neonPurple400, dark: UIColor.Dolby.neonPurple400))
}

// MARK: Icon attribute definitions
extension DefaultTheme {
    public func iconAttribute() -> IconAttribute {
        return _iconAttribute
    }

    private func iconAttributeValue() -> IconAttribute {
        return IconAttribute(tintColor: onBackground,
                                   focusedTintColor: onBackground)
    }

}

// MARK: Toggle attribute definitions
extension DefaultTheme {
    public func toggleAttribute() -> ToggleAttribute {
        return _toggleAttribute
    }

    private func toggleAttributeValue() -> ToggleAttribute {
        return ToggleAttribute(textColor: onBackground,
                               tintColor: onBackground,
                               focusedBackgroundColor: onBackground,
                               outlineColor: onBackground)
    }
}

// MARK: Text attribute definitions
extension DefaultTheme {
    public func textAttribute(for textStyle: TextStyles) -> TextAttribute {
        switch textStyle {
        case .displayLarge:
            return _primaryTextAttribute
        case .displayMedium:
            return _primaryTextAttribute
        case .displaySmall:
            return _primaryTextAttribute
        case .headlineLarge:
            return _primaryTextAttribute
        case .headlineMedium:
            return _primaryTextAttribute
        case .headlineSmall:
            return _primaryTextAttribute
        case .titleLarge:
            return _primaryTextAttribute
        case .titleMedium:
            return _primaryTextAttribute
        case .titleSmall:
            return _primaryTextAttribute
        case .labelLarge:
            return _secondaryTextAttribute
        case .labelMedium:
            return _secondaryTextAttribute
        case .labelSmall:
            return _secondaryTextAttribute
        case .bodyLarge:
            return _secondaryTextAttribute
        case .bodyMedium:
            return _secondaryTextAttribute
        case .bodySmall:
            return _secondaryTextAttribute
        }
    }

    private func primaryTextAttribute() -> TextAttribute {
        return TextAttribute(textColor: onBackground)
    }

    private func secondaryTextAttribute() -> TextAttribute {
        return TextAttribute(textColor: onBackground)
    }

    private func tertiaryTextAttribute() -> TextAttribute {
        return TextAttribute(textColor: onBackground)
    }
}

// MARK: TextField attribute definitions
extension DefaultTheme {

    public func textFieldAttribute() -> TextFieldAttribute {
        return _textFieldAttribute
    }

    private func textFieldAttributeValue() -> TextFieldAttribute {
        return TextFieldAttribute(textColor: onBackground, placeHolderTextColor: onBackground, tintColor: onBackground, outlineColor: onBackground, activeOutlineColor: onBackground, errorOutlineColor: onBackground, disabledBackgroundColor: onBackground, errorMessageColor: onBackground)
    }
}
// swiftlint:enable cyclomatic_complexity
