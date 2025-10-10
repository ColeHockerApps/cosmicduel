import SwiftUI
import Combine

/// Global theme manager: handles light/dark/system preference.
final class ThemeManager: ObservableObject {
    
    enum AppTheme: String, CaseIterable {
        case system
        case light
        case dark
    }
    
    @AppStorage("themePreference") private var storedTheme: String = AppTheme.system.rawValue {
        didSet {
            if let t = AppTheme(rawValue: storedTheme) {
                currentTheme = t
            }
        }
    }
    
    @Published private(set) var currentTheme: AppTheme = .system
    
    init() {
        if let t = AppTheme(rawValue: storedTheme) {
            currentTheme = t
        } else {
            currentTheme = .system
        }
    }
    
    /// Returns value suitable for `.preferredColorScheme(...)`
    var currentColorScheme: ColorScheme? {
        switch currentTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        storedTheme = theme.rawValue
        currentTheme = theme
        objectWillChange.send()
    }
    
    func toggleTheme() {
        switch currentTheme {
        case .system: setTheme(.light)
        case .light:  setTheme(.dark)
        case .dark:   setTheme(.system)
        }
    }
}
