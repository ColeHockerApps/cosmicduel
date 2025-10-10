import SwiftUI

struct HowToPlayView: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Header()

                SectionCard(title: "Controls") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("Hold left half to thrust LEFT rocket.")
                        } icon: { Icon("hand.tap.fill") }

                        Label {
                            Text("Hold right half to thrust RIGHT rocket.")
                        } icon: { Icon("hand.tap.fill") }

                        Label {
                            Text("Swipe horizontally to DASH (short cooldown).")
                        } icon: { Icon("arrow.right.arrow.left.circle.fill") }

                        Label {
                            Text("Avoid asteroids and mines. Touch = hit.")
                        } icon: { Icon("exclamationmark.triangle.fill") }
                    }
                }

                SectionCard(title: "Game Modes") {
                    VStack(alignment: .leading, spacing: 10) {
                        ModeRow(title: "Duel (1v1 PvP)",
                                text: "Two players on one device. Last survivor wins. Best-of-3.")
                        ModeRow(title: "Solo Survival",
                                text: "Survive as long as possible. Try to beat your best time.")
                        ModeRow(title: "Time Attack",
                                text: "Score the most before time runs out. Solo or Duel.")
                        ModeRow(title: "Sudden Death",
                                text: "One hit = KO. Short, tense rounds. Best-of-5.")
                    }
                }

                SectionCard(title: "Tips") {
                    VStack(alignment: .leading, spacing: 10) {
                        TipRow(text: "Short, rhythmic thrusts give better control than holding constantly.")
                        TipRow(text: "Use dash to sidestep incoming obstacles at the last moment.")
                        TipRow(text: "Mines push you — even if they don't KO immediately, they can throw you off course.")
                        TipRow(text: "In Time Attack, focus on safe gates rather than risky ones.")
                        TipRow(text: "Try different themes and haptics in Settings to your taste.")
                    }
                }

                SectionCard(title: "HUD & Match") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("Timer shows remaining time (or total survival time in Solo).")
                        } icon: { Icon("timer") }
                        Label {
                            Text("Series counters show round wins (L/R).")
                        } icon: { Icon("medal.fill") }
                        Label {
                            Text("Pause with the Pause button. Rematch or Next Round at the bottom.")
                        } icon: { Icon("pause.fill") }
                    }
                }
            }
            .padding(16)
            .foregroundStyle(ColorTokens.textPrimary.color)
        }
        .background(ColorTokens.background.color.ignoresSafeArea())
        .navigationTitle("How to Play")
        .preferredColorScheme(theme.currentColorScheme)
    }

    // MARK: - Subviews
    @ViewBuilder
    private func Header() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome, Pilot!")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            Text("Master the thrust, time your dashes, and outlive your opponent.")
                .foregroundStyle(ColorTokens.textSecondary.color)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func SectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .background(ColorTokens.hudBackground.color)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func ModeRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.bold())
            Text(text)
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary.color)
        }
    }

    @ViewBuilder
    private func TipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.max.fill")
                .foregroundStyle(ColorTokens.accentOrange.color)
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 1)
            Text(text)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func Icon(_ name: String) -> some View {
        Image(systemName: name)
            .foregroundStyle(ColorTokens.accentBlue.color)
            .font(.system(size: 16, weight: .bold))
            .frame(width: 22, height: 22)
    }
}
