import Foundation
import Combine
import SwiftUI

/// Two sides for PvP.
enum Side: String {
    case left
    case right
}

/// High-level state of a round lifecycle.
enum RoundPhase: String {
    case idle
    case countdown
    case playing
    case paused
    case finished
}

/// Public winner enum for round results.
enum RoundWinner: Equatable {
    case left
    case right
    case solo
    case tie
}

/// Central match/round state shared between UI and game scene.
final class MatchState: ObservableObject {

    // MARK: - Inputs / Dependencies
    @Published var settings = GameSettings()

    // MARK: - Mode & Rules
    @Published private(set) var mode: GameMode = .duel
    @Published private(set) var rules: ModeRules = DefaultModeRules.rules(for: .duel)

    // MARK: - Round & Series
    @Published private(set) var phase: RoundPhase = .idle
    @Published private(set) var roundIndex: Int = 0
    @Published private(set) var leftWins: Int = 0
    @Published private(set) var rightWins: Int = 0

    // Time / Progress
    @Published private(set) var roundTimeRemaining: TimeInterval? = nil
    @Published private(set) var roundTimeElapsed: TimeInterval = 0
    @Published private(set) var roundProgress: Double? = nil

    // Scoring
    @Published private(set) var leftScore: Int = 0
    @Published private(set) var rightScore: Int = 0

    // Last winner
    @Published private(set) var lastRoundWinner: RoundWinner? = nil

    // MARK: - Solo High Scores
    @AppStorage("records.soloSurvival.bestTimeSec") private var storedBestSurvivalTime: Double = 0
    @AppStorage("records.timeAttackSolo.bestScore") private var storedBestTimeAttackScore: Int = 0

    @Published private(set) var bestSurvivalTimeSec: Double = 0
    @Published private(set) var bestTimeAttackScore: Int = 0

    // MARK: - Rocket paints
    @Published private(set) var leftRocketPaint: RocketPaint = RocketPaint(top: .white, bottom: .lightGray)
    @Published private(set) var rightRocketPaint: RocketPaint = RocketPaint(top: .white, bottom: .darkGray)

    // MARK: - Timer
    private var timerCancellable: AnyCancellable?
    private let tickInterval: TimeInterval = 0.05

    // MARK: - Scene hooks
    var isPlaying: Bool { phase == .playing }

    func addScore(to side: Side, amount: Int = 1) {
        guard rules.winBy == .scoreMost else { return }
        switch side {
        case .left:  leftScore = max(0, leftScore + amount)
        case .right: rightScore = max(0, rightScore + amount)
        }
        Haptics.shared.success()
    }

    func endRound(winner: RoundWinner) {
        guard phase == .playing || phase == .paused else { return }
        stopTimer()

        switch mode {
        case .duel, .timeAttackDuel:
            if winner == .left { leftWins += 1 }
            else if winner == .right { rightWins += 1 }
        case .suddenDeath:
            if winner == .left { leftWins += 1 }
            else if winner == .right { rightWins += 1 }
        case .soloSurvival:
            let elapsed = roundTimeElapsed
            if elapsed > storedBestSurvivalTime {
                storedBestSurvivalTime = elapsed
                bestSurvivalTimeSec = elapsed
                Haptics.shared.success()
            }
        case .timeAttackSolo:
            if leftScore > storedBestTimeAttackScore {
                storedBestTimeAttackScore = leftScore
                bestTimeAttackScore = leftScore
                Haptics.shared.success()
            }
        }

        lastRoundWinner = winner
        phase = .finished
        Haptics.shared.success()
    }

    func pauseRound() {
        guard phase == .playing else { return }
        phase = .paused
        stopTimer()
    }

    func resumeRound() {
        guard phase == .paused else { return }
        phase = .playing
        startTimer()
    }

    // MARK: - Public Match Control
    func startMatch(mode newMode: GameMode) {
        mode = newMode
        leftWins = 0
        rightWins = 0
        lastRoundWinner = nil

        bestSurvivalTimeSec = storedBestSurvivalTime
        bestTimeAttackScore = storedBestTimeAttackScore

        // Assign rocket paints
        assignRocketPaints(for: newMode)

        rules = makeRules(for: newMode)
        roundIndex = 0
        startRound()
    }

    private func assignRocketPaints(for mode: GameMode) {
        let all = GameConstants.Colors.rocketGradientPairs
        guard !all.isEmpty else {
            leftRocketPaint = RocketPaint(top: .white, bottom: .lightGray)
            rightRocketPaint = RocketPaint(top: .white, bottom: .darkGray)
            return
        }

        if mode == .duel || mode == .timeAttackDuel {
            // two different randoms
            var shuffled = all.shuffled()
            leftRocketPaint = shuffled.removeFirst()
            rightRocketPaint = shuffled.removeFirst()
        } else {
            // solo: both the same
            leftRocketPaint = all.randomElement()!
            rightRocketPaint = leftRocketPaint
        }
    }

    func startRound() {
        stopTimer()
        leftScore = 0
        rightScore = 0
        roundTimeElapsed = 0
        lastRoundWinner = nil

        rules = makeRules(for: mode)

        if let duration = rules.roundDurationSec {
            roundTimeRemaining = TimeInterval(duration)
            roundProgress = 0
        } else {
            roundTimeRemaining = nil
            roundProgress = nil
        }

        phase = .playing
        Haptics.shared.selectionChanged()
        startTimer()
    }

    func nextRoundOrEndSeries() {
        if isSeriesComplete { return }
        roundIndex += 1
        startRound()
    }

    var isSeriesComplete: Bool {
        switch rules.series {
        case .singleRound: return phase == .finished
        case .bestOf(let n):
            let need = n / 2 + 1
            return leftWins >= need || rightWins >= need
        }
    }

    var matchWinner: RoundWinner? {
        guard isSeriesComplete else { return nil }
        switch rules.series {
        case .singleRound: return lastRoundWinner
        case .bestOf:
            if leftWins > rightWins { return .left }
            if rightWins > leftWins { return .right }
            return .tie
        }
    }

    func rematch() {
        startMatch(mode: mode)
    }

    func appDidBecomeActive() {
        if phase == .paused {
            resumeRound()
        }
    }

    func appDidEnterBackground() {
        if phase == .playing {
            pauseRound()
        }
    }

    // MARK: - Timer
    private func startTimer() {
        stopTimer()
        timerCancellable = Timer.publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard phase == .playing else { return }

        roundTimeElapsed += tickInterval

        if var remaining = roundTimeRemaining {
            remaining -= tickInterval
            roundTimeRemaining = max(0, remaining)
            if let total = rules.roundDurationSec {
                roundProgress = max(0, min(1, (Double(total) - remaining) / Double(total)))
            }
            if remaining <= 0 {
                switch mode {
                case .duel, .suddenDeath: endRound(winner: .tie)
                case .timeAttackSolo: endRound(winner: .solo)
                case .timeAttackDuel:
                    if leftScore > rightScore { endRound(winner: .left) }
                    else if rightScore > leftScore { endRound(winner: .right) }
                    else { endRound(winner: .tie) }
                case .soloSurvival: break
                }
            }
        } else {
            roundProgress = nil
        }
    }

    private func makeRules(for mode: GameMode) -> ModeRules {
        let globalOneHit = settings.oneHitKOGlobal
        switch mode {
        case .duel:
            return DefaultModeRules.rules(for: mode,
                                          globalOneHit: globalOneHit,
                                          userRoundDuration: settings.roundDurationSec)
        case .timeAttackSolo, .timeAttackDuel:
            return DefaultModeRules.rules(for: mode,
                                          globalOneHit: globalOneHit,
                                          userTimeAttackDuration: settings.timeAttackDurationSec)
        case .suddenDeath, .soloSurvival:
            return DefaultModeRules.rules(for: mode, globalOneHit: globalOneHit)
        }
    }
}
