//
//  Button.swift
//

import SwiftUI

public struct Button: View {
    public enum ButtonState {
        case `default`
        case loading
        case success
    }

    public var action: () -> Void
    public var text: LocalizedStringKey

    public var leftIcon: IconAsset?
    public var rightIcon: IconAsset?
    public var style: ButtonStyles

    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding public var buttonState: ButtonState
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var hover = false
    @FocusState private var isFocused: Bool

    private var theme: Theme {
        themeManager.theme
    }

    private var containerColor: Color? {
        guard isEnabled == true else {
            return theme.onSurface
        }

        if isFocused {
            return theme.onPrimary
        }

        return theme.primary
    }
    
    private var containerShadowColor: Color? {
        return nil
    }
    
    private var labelTextColor: Color? {
        guard isEnabled == true else {
            return theme.onSurface
        }

        if isFocused {
            return theme.onPrimary
        }

        return theme.onPrimary
    }
    
    private var iconColor: Color? {
        guard isEnabled == true else {
            return theme.onSurface
        }

        if isFocused {
            return theme.onPrimary
        }

        return theme.onPrimary
    }
    
    var font: Font {
        #if os(tvOS)
        theme[.avenirNextDemiBold(size: FontSize.caption2, withStyle: .caption2)]
        #else
        .custom("AvenirNext-DemiBold", size: FontSize.subhead, relativeTo: .subheadline)
        #endif
    }
    
    public init(
        action: @escaping () -> Void,
        text: LocalizedStringKey,
        leftIcon: IconAsset? = nil,
        rightIcon: IconAsset? = nil,
        style: ButtonStyles = .primary,
        buttonState: Binding<ButtonState> = .constant(.default)
    ) {
        self.action = action
        self.text = text
        self.leftIcon = leftIcon
        self.rightIcon = rightIcon
        self.style = style
        self._buttonState = buttonState
    }
    
    public var body: some View {
        buttonView
    }
}

// MARK: Private helper functions

private extension Button {
    var buttonView: some View {
        SwiftUI.Button(action: action) {
            content()
        }
        .focused($isFocused)
        .accessibilityLabel(accessibilityLabel)
#if os(tvOS)
        .buttonStyle(
            ClearButtonStyle(
                isFocused: isFocused,
                focusedBackgroundColor: .clear
            )
        )
#else
        .buttonStyle(.plain)
#endif
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius6x)
        )
        .background(containerColor)
        .mask(RoundedRectangle(cornerRadius: Layout.cornerRadius6x))
    }

    var accessibilityLabel: String {
        switch buttonState {
        case .default:
            return text.toString()
        case .loading:
            return "Loading..."
        case .success:
            return "Success"
        }
    }
    
    @ViewBuilder
    private func content() -> some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
            HStack(spacing: Layout.spacing2x) {
                if let leftIcon = leftIcon {
                    IconView(
                        iconAsset: leftIcon,
                        tintColor: iconColor
                    )
                }

                SwiftUI.Text(text)
                    .font(font)
                    .textCase(.uppercase)
                    .foregroundColor(labelTextColor)

                if let rightIcon = rightIcon {
                    IconView(
                        iconAsset: rightIcon,
                        tintColor: iconColor
                    )
                }
            }
            .opacity(buttonState == .default ? 1.0 : 0.0)

            LoadingView(
                tintColor: iconColor
            )
            .opacity(buttonState == .loading ? 1.0 : 0.0)

            IconView(
                iconAsset: .success,
                tintColor: iconColor
            )
            .opacity(buttonState == .success ? 1.0 : 0.0)
        }
        .padding(.vertical, Layout.spacing1x)
        .padding(.horizontal, Layout.spacing4x)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(containerColor)
    }
}

#if DEBUG
struct PrimaryButton_Previews: PreviewProvider {

    static var previews: some View {
        Group {

            // MARK: Primary Buttons
            VStack {
                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    buttonState: .constant(.default)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    buttonState: .constant(.loading)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    buttonState: .constant(.success)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    buttonState: .constant(.default)
                )
                .disabled(true)
            }

            // MARK: Primary Danger Buttons
            VStack {
                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY DANGER BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .primaryDanger,
                    buttonState: .constant(.default)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "PRIMARY DANGER BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .primaryDanger,
                    buttonState: .constant(.default)
                )
                .disabled(true)
            }

            // MARK: Secondary Buttons

            VStack {
                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondary,
                    buttonState: .constant(.default)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondary,
                    buttonState: .constant(.loading)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondary,
                    buttonState: .constant(.success)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondary,
                    buttonState: .constant(.default)
                )
                .disabled(true)
            }

            // MARK: Secondary Danger Buttons

            VStack {

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY DANGER BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondaryDanger,
                    buttonState: .constant(.default)
                )

                Button(
                    action: {
                        print("Pressed Button 1")
                    },
                    text: "SECONDARY DANGER BUTTON TEXT",
                    leftIcon: .arrowLeft,
                    rightIcon: .arrowRight,
                    style: .secondaryDanger,
                    buttonState: .constant(.default)
                )
                .disabled(true)
            }
        }

    }
}
#endif
