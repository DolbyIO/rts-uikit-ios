//
//  ColorAttributes.swift
// 

import SwiftUI

// MARK: Text Colors

public struct TextAttribute {
    let textColor: Color
}

// MARK: TextField Colors

public struct TextFieldAttribute {
    let textColor: Color
    let placeHolderTextColor: Color
    let tintColor: Color
    let outlineColor: Color
    let activeOutlineColor: Color
    let errorOutlineColor: Color
    let disabledBackgroundColor: Color
    let errorMessageColor: Color
}

// MARK: Toggle Colors

public struct ToggleAttribute {
    let textColor: Color
    let tintColor: Color
    let focusedBackgroundColor: Color
    let outlineColor: Color
}

// MARK: IconAttribute Colors

public struct IconAttribute {
    let tintColor: Color
    let focusedTintColor: Color
}
