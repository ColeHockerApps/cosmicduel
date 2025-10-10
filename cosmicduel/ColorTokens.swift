import SwiftUI
import UIKit

/// Centralized color tokens for SwiftUI + SpriteKit.
/// Use `ColorTokens` in SwiftUI, or `ColorTokens.*.uiColor` in SpriteKit.
enum ColorTokens {

    // MARK: - Backgrounds
    static var background: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.93, green: 0.95, blue: 0.96),   // #EAECF0
                      dark:  Color(red: 0.06, green: 0.09, blue: 0.15))   // #0F1826
    }

    static var hudBackground: AdaptiveColor {
        AdaptiveColor(light: Color.white.opacity(0.85),
                      dark:  Color.black.opacity(0.65))
    }

    // MARK: - Text
    static var textPrimary: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.15, green: 0.15, blue: 0.15),   // #262626
                      dark:  Color(red: 0.93, green: 0.93, blue: 0.93))   // #EDEDED
    }

    static var textSecondary: AdaptiveColor {
        AdaptiveColor(light: Color.gray.opacity(0.75),
                      dark:  Color.gray.opacity(0.65))
    }

    // MARK: - Accents
    static var accentBlue: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.18, green: 0.53, blue: 0.96),   // #2E87F5
                      dark:  Color(red: 0.30, green: 0.62, blue: 0.99))   // #4FA0FD
    }

    static var accentOrange: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.98, green: 0.56, blue: 0.19),   // #FA8F31
                      dark:  Color(red: 1.0, green: 0.62, blue: 0.25))    // #FF9E40
    }

    static var accentRed: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.92, green: 0.26, blue: 0.26),   // #EB4343
                      dark:  Color(red: 0.96, green: 0.36, blue: 0.36))   // #F55C5C
    }

    static var accentGreen: AdaptiveColor {
        AdaptiveColor(light: Color(red: 0.23, green: 0.72, blue: 0.32),   // #3AB951
                      dark:  Color(red: 0.34, green: 0.82, blue: 0.43))   // #57D26E
    }

    // MARK: - Overlays
    static var overlay: AdaptiveColor {
        AdaptiveColor(light: Color.black.opacity(0.05),
                      dark:  Color.white.opacity(0.08))
    }
}

/// Wrapper that returns correct color depending on system scheme.
struct AdaptiveColor {
    let light: Color
    let dark: Color

    var color: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    var uiColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        }
    }
}
