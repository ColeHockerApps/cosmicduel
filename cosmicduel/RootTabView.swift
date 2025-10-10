import SwiftUI

/// Корневой контейнер с нижним таббаром:
/// - Home: главный экран с режимами (MainMenuView)
/// - Settings: настройки + privacy
/// - How To: краткая справка
///
/// Каждый таб обёрнут в свой NavigationStack, чтобы навигация внутри табов была независимой.
struct RootTabView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var match: MatchState

    enum Tab: Hashable {
        case home, settings, howto
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {

            // HOME
            NavigationStack {
                MainMenuView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)

            // SETTINGS
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)

            // HOW TO PLAY
            NavigationStack {
                HowToPlayView()
            }
            .tabItem {
                Label("How To", systemImage: "questionmark.circle.fill")
            }
            .tag(Tab.howto)
        }
        .onChange(of: selection) { _ in
            Haptics.shared.selectionChanged()
        }
        .tint(ColorTokens.accentBlue.color)
        .preferredColorScheme(theme.currentColorScheme)
        .background(ColorTokens.background.color.ignoresSafeArea())
    }
}
