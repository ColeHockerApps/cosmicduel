import SwiftUI

struct HUDOverlay: View {
    @EnvironmentObject private var match: MatchState
    @EnvironmentObject private var theme: ThemeManager

    // Callbacks from host (GameView)
    var onBack: (() -> Void)?
    var onRematch: (() -> Void)?
    var onNextRound: (() -> Void)?

    var body: some View {
        ZStack {
            // CENTER — показываем только после завершения
            if match.phase == .finished {
                CenterFinished()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ColorTokens.textPrimary.color)
        .preferredColorScheme(theme.currentColorScheme)
        .animation(.spring(response: GameConstants.UI.resultSpringResponse,
                           dampingFraction: GameConstants.UI.resultSpringDamping),
                   value: match.phase)
        // TOP — прибит к safe area
        .overlay(alignment: .top) {
            TopBar()
                .padding(.horizontal, GameConstants.UI.hudHorizontalPadding)
                .padding(.top, 8)
        }
        // BOTTOM — только Next Round; задизейблен до финиша
        .overlay(alignment: .bottom) {
            BottomBar()
                .padding(.horizontal, GameConstants.UI.hudHorizontalPadding)
                .padding(.bottom, 10)
        }
    }

    // MARK: - TOP BAR (Menu • center info). Кнопка Pause удалена.
    @ViewBuilder
    private func TopBar() -> some View {
        HStack(spacing: 12) {
            // MENU (лево)
            let menu = Button {
                Haptics.shared.selectionChanged()
                onBack?()
            } label: {
                Label("Menu", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(ColorTokens.hudBackground.color)
                    .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: true, vertical: false)
            }

            menu

            Spacer(minLength: 12)

            // CENTER INFO
            Group {
                switch match.mode {
                case .timeAttackSolo, .timeAttackDuel:
                    TimeAttackCenter()
                case .soloSurvival:
                    SurvivalCenter()
                default:
                    DuelCenter()
                }
            }
            .layoutPriority(1)
            .minimumScaleFactor(0.85)

            Spacer(minLength: 12)

            // «Пустышка» справа, чтобы центр был ровно по центру (симметрия с Menu)
            menu.hidden()
        }
    }

    // MARK: - BOTTOM BAR (no Rematch; only Next Round; disabled while playing/paused)
    @ViewBuilder
    private func BottomBar() -> some View {
        VStack(spacing: 10) {
            if match.phase == .paused {
                Text("Paused")
                    .font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(ColorTokens.hudBackground.color)
                    .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            }

            if !match.isSeriesComplete {
                let enabled = (match.phase == .finished)
                Button {
                    if enabled {
                        Haptics.shared.selectionChanged()
                        onNextRound?()
                    }
                } label: {
                    Label("Next Round", systemImage: "forward.end.fill")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(ColorTokens.hudBackground.color)
                        .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
            }
        }
    }

    // MARK: - CENTER after finish: Finished • Result • Rematch/Menu
    @ViewBuilder
    private func CenterFinished() -> some View {
        VStack(spacing: 16) {
            // 1) Заголовок «Finished» (фиксировано по ТЗ)
            Text("Finished")
                .font(.title2.bold())
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(ColorTokens.hudBackground.color)
                .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                .fixedSize(horizontal: true, vertical: false)

            // 2) Итог раунда: в SOLO показываем "Good job!"
            ResultBanner()

            // 3) Кнопки Rematch и Menu
            HStack(spacing: 12) {
                Button {
                    Haptics.shared.selectionChanged()
                    onRematch?()
                } label: {
                    Text("Rematch")
                        .font(.headline)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(ColorTokens.hudBackground.color)
                        .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                        .fixedSize(horizontal: true, vertical: false)
                }

                Button {
                    Haptics.shared.selectionChanged()
                    onBack?()
                } label: {
                    Text("Menu")
                        .font(.headline)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(ColorTokens.hudBackground.color)
                        .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.horizontal, 20)
        .multilineTextAlignment(.center)
    }

    // MARK: - Result banner (SOLO => "Good job!")
    @ViewBuilder
    private func ResultBanner() -> some View {
        let isSolo = (match.mode == .soloSurvival || match.mode == .timeAttackSolo)
        let title: String = {
            if isSolo {
                return "Good job!"
            }
            switch match.lastRoundWinner {
            case .left?: return "Left Wins!"
            case .right?: return "Right Wins!"
            case .tie?: return "Tie"
            case .solo?: return "Good job!"   // на всякий случай
            case nil: return "Finished"
            }
        }()

        Text(title)
            .font(.title3.bold())
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(ColorTokens.hudBackground.color)
            .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Centers (top middle)
    @ViewBuilder
    private func DuelCenter() -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                SeriesPill(text: "L \(match.leftWins)", color: ColorTokens.accentBlue.color)
                SeriesPill(text: "R \(match.rightWins)", color: ColorTokens.accentOrange.color)
            }
            if let remaining = match.roundTimeRemaining {
                TimerPill(remaining: remaining)   // ← без progress
                    .frame(maxWidth: 160)
            }
        }
    }

    @ViewBuilder
    private func SurvivalCenter() -> some View {
        let elapsed = match.roundTimeElapsed
        VStack(spacing: 6) {
            Text(timeString(elapsed))
                .font(.headline.monospacedDigit())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(ColorTokens.hudBackground.color)
                .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            if match.bestSurvivalTimeSec > 0 {
                Text("Best \(timeString(match.bestSurvivalTimeSec))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(ColorTokens.textSecondary.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(ColorTokens.hudBackground.color.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            }
        }
    }

    @ViewBuilder
    private func TimeAttackCenter() -> some View {
        switch match.mode {
        case .timeAttackDuel:
            VStack(spacing: 6) {
                if let remaining = match.roundTimeRemaining {
                    TimerPill(remaining: remaining)
                        .frame(maxWidth: 180)
                }
                HStack(spacing: 8) {
                    ScorePill(text: "\(match.leftScore)", color: ColorTokens.accentBlue.color)
                    ScorePill(text: "\(match.rightScore)", color: ColorTokens.accentOrange.color)
                }
            }

        case .timeAttackSolo:
            VStack(spacing: 6) {
                if let remaining = match.roundTimeRemaining {
                    TimerPill(remaining: remaining)
                        .frame(maxWidth: 180)
                }
                if match.bestTimeAttackScore > 0 {
                    Text("Best \(match.bestTimeAttackScore)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(ColorTokens.textSecondary.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(ColorTokens.hudBackground.color.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
                }
                ScorePill(text: "\(match.leftScore)", color: ColorTokens.accentBlue.color)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Small pieces
    @ViewBuilder
    private func SeriesPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.headline.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    @ViewBuilder
    private func ScorePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.headline.monospacedDigit().weight(.bold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    @ViewBuilder
    private func TimerPill(remaining: TimeInterval) -> some View {
        Text(timeString(remaining))
            .font(.headline.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(ColorTokens.hudBackground.color)
            .clipShape(RoundedRectangle(cornerRadius: GameConstants.UI.hudCornerRadius))
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(round(t)))
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}
