//
//  Theme.swift
//  
import SwiftUI

public protocol Theme {
    // Material theme color definitions
    var primary: Color { get }
    var primaryContainer: Color { get }
    var onPrimary: Color { get }
    var onPrimaryContainer: Color { get }
    var inversePrimary: Color { get }
    var secondary: Color { get }
    var secondaryContainer: Color { get }
    var onSecondary: Color { get }
    var onSecondaryContainer: Color { get }
    var tertiary: Color { get }
    var tertiaryContainer: Color { get }
    var onTertiaryContainer: Color { get }
    var surface: Color { get }
    var surfaceDim: Color { get }
    var surfaceBright: Color { get }
    var surfaceContainerLowest: Color { get }
    var surfaceContainerLow: Color { get }
    var surfaceContainer: Color { get }
    var surfaceContainerHigh: Color { get }
    var surfaceContainerHighest: Color { get }
    var surfaceVariant: Color { get }
    var onSurface: Color { get }
    var onSurfaceVariant: Color { get }
    var inverseSurface: Color { get }
    var inverseOnSurface: Color { get }
    var background: Color { get }
    var onBackground: Color { get }
    var error: Color { get }
    var errorContainer: Color { get }
    var onError: Color { get }
    var onErrorContainer: Color { get }
    var outline: Color { get }
    var outlineVariant: Color { get }
    var shadow: Color { get }
    var surfaceTint: Color { get }
    var scrim: Color { get }

    func iconAttribute() -> IconAttribute
    func toggleAttribute() -> ToggleAttribute
    func textAttribute(for textStyle: TextStyles) -> TextAttribute
    func textFieldAttribute() -> TextFieldAttribute
}

public enum ButtonStyles {
    case primary
    case primaryDanger
    case secondary
    case secondaryDanger
    case tertiary
}

public enum TextStyles {
    case displayLarge
    case displayMedium
    case displaySmall
    case headlineLarge
    case headlineMedium
    case headlineSmall
    case titleLarge
    case titleMedium
    case titleSmall
    case labelLarge
    case labelMedium
    case labelSmall
    case bodyLarge
    case bodyMedium
    case bodySmall
}
