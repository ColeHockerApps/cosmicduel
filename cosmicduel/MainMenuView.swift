import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var match: MatchState
    @EnvironmentObject private var theme: ThemeManager

    @State private var navigateToGame = false
    @State private var showTimeAttackPicker = false

    var body: some View {
        ZStack {
            ColorTokens.background.color.ignoresSafeArea()

            VStack(spacing: 20) {
                // Title: ROCKET DUEL
                VStack(spacing: 6) {
                    Text("Duel")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .kerning(2)
                    Text("Rockets")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [
                                ColorTokens.accentBlue.color,
                                ColorTokens.accentOrange.color
                            ], startPoint: .leading, endPoint: .trailing)
                        )
                        .kerning(3)
                }
                .padding(.top, 24)

                // Play cards
                VStack(spacing: 12) {
                    ModeButton(
                        title: "Duel (1v1 PvP)",
                        subtitle: "Two players on one device. Last survivor wins.",
                        icon: "person.2.fill",
                        tint: ColorTokens.accentBlue.color
                    ) {
                        Haptics.shared.selectionChanged()
                        start(mode: .duel)
                    }

                    ModeButton(
                        title: "Solo Survival",
                        subtitle: "Survive as long as possible. Beat your best time.",
                        icon: "heart.text.square.fill",
                        tint: ColorTokens.accentGreen.color
                    ) {
                        Haptics.shared.selectionChanged()
                        start(mode: .soloSurvival)
                    }

                    ModeButton(
                        title: "Time Attack",
                        subtitle: "Score the most before time runs out.",
                        icon: "hourglass",
                        tint: ColorTokens.accentRed.color
                    ) {
                        Haptics.shared.selectionChanged()
                        showTimeAttackPicker = true
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 24)

                // Hidden navigation to game
                NavigationLink(isActive: $navigateToGame) {
                    GameView()
                        .environmentObject(match)
                        .environmentObject(theme)
                } label: { EmptyView() }
                .hidden()
            }
            .foregroundStyle(ColorTokens.textPrimary.color)
        }
        .preferredColorScheme(theme.currentColorScheme)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Time Attack", isPresented: $showTimeAttackPicker, titleVisibility: .visible) {
            Button("Time Attack (Solo)") {
                Haptics.shared.selectionChanged()
                start(mode: .timeAttackSolo)
            }
            Button("Time Attack (Duel)") {
                Haptics.shared.selectionChanged()
                start(mode: .timeAttackDuel)
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func start(mode: GameMode) {
        match.startMatch(mode: mode)
        navigateToGame = true
    }
}

// MARK: - Helper views (kept in the same file)

private struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary.color)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.textSecondary.color)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorTokens.hudBackground.color)
            )
        }
        .buttonStyle(.plain)
    }
}
