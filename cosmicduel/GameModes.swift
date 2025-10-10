import Foundation
import CoreGraphics

/// All supported game modes in Cosmic Duel.
enum GameMode: String, CaseIterable, Identifiable {
    case duel                 // 1v1 PvP, last survivor wins
    case soloSurvival         // single player, survive as long as possible
    case timeAttackSolo       // single player, score as much as possible within time
    case timeAttackDuel       // PvP, highest score within time wins
    case suddenDeath          // 1-hit KO, fast rounds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duel:            return "Duel (1v1 PvP)"
        case .soloSurvival:    return "Solo Survival"
        case .timeAttackSolo:  return "Time Attack (Solo)"
        case .timeAttackDuel:  return "Time Attack (Duel)"
        case .suddenDeath:     return "Sudden Death"
        }
    }

    var shortDescription: String {
        switch self {
        case .duel:
            return "Two players on one device. Last survivor wins."
        case .soloSurvival:
            return "Survive as long as possible. Beat your best time."
        
        case .timeAttackSolo:
            return "Score as much as possible before time runs out."
        case .timeAttackDuel:
            return "Highest score within time wins the round."
        case .suddenDeath:
            return "One hit = KO. Fast, tense duels."
        }
    }
}

/// How a round is won.
enum WinCondition: Equatable {
    case surviveLast       // last survivor (KO or timeout tiebreakers)
    case scoreMost         // highest score within time
    case timeLongest       // longest survival time (endless)
}

/// How scoring works for a mode (used mainly by Time Attack).
struct ScoringRules: Equatable {
    var gateScore: Int = 1         // points for passing a gate/collectible
    var collisionPenalty: Int = 0  // optional penalty on hit (if applicable)
    var bonusOnStreak: Int = 0     // optional streak bonus
}

/// Series format for multi-round matches.
enum SeriesFormat: Equatable {
    case singleRound
    case bestOf(Int) // e.g., bestOf(3), bestOf(5)
}

/// Spawn curve configuration across a round's timeline.
/// Speeds are abstract multipliers the scene will map to actual timings.
struct SpawnCurve: Equatable {
    /// Spawn interval (seconds) at the beginning of the round.
    var startSpawnInterval: TimeInterval
    /// Spawn interval (seconds) at the end of the round.
    var endSpawnInterval: TimeInterval
    /// Max simultaneous obstacles allowed (soft cap).
    var maxSimultaneous: Int

    /// Linear interpolation of spawn interval by progress 0...1
    func interval(at progress: Double) -> TimeInterval {
        let p = max(0, min(1, progress))
        return startSpawnInterval + (endSpawnInterval - startSpawnInterval) * p
    }
}

/// Round rules for a given GameMode.
struct ModeRules: Equatable {
    var winBy: WinCondition
    var series: SeriesFormat
    var roundDurationSec: Int?      // nil = infinite (used by Solo Survival)
    var livesPerPlayer: Int?        // nil = not used; if oneHit is true, lives are ignored
    var oneHit: Bool                // true for Sudden Death, overrides lives
    var scoring: ScoringRules       // used by modes that score points
    var spawn: SpawnCurve           // difficulty progression over time
    var botEnabled: Bool            // whether a bot opponent is active
    var allowTies: Bool             // whether ties are possible at round end

    /// Convenience: whether the round is time-limited.
    var isTimed: Bool { roundDurationSec != nil }
}

/// Default rules mapping per mode.
/// Scene should treat these as authoritative unless overridden by user settings (e.g., global One-hit toggle).
enum DefaultModeRules {

    static func rules(for mode: GameMode,
                      globalOneHit: Bool = false,
                      userRoundDuration: Int? = nil,    // optional override for Duel/SoloBot
                      userTimeAttackDuration: Int? = nil // optional override for Time Attack
    ) -> ModeRules {
        switch mode {

        case .duel:
            return ModeRules(
                winBy: .surviveLast,
                series: .bestOf(3),
                roundDurationSec: userRoundDuration ?? 60,
                livesPerPlayer: globalOneHit ? nil : 1,
                oneHit: globalOneHit ? true : false,
                scoring: ScoringRules(),
                spawn: SpawnCurve(startSpawnInterval: 0.9, endSpawnInterval: 0.6, maxSimultaneous: 10),
                botEnabled: false,
                allowTies: false
            )

        case .soloSurvival:
            return ModeRules(
                winBy: .timeLongest,
                series: .singleRound,
                roundDurationSec: nil, // infinite
                livesPerPlayer: globalOneHit ? nil : 1,
                oneHit: globalOneHit ? true : false,
                scoring: ScoringRules(),
                spawn: SpawnCurve(startSpawnInterval: 1.2, endSpawnInterval: 0.7, maxSimultaneous: 11),
                botEnabled: false,
                allowTies: true
            )

        

        case .timeAttackSolo:
            return ModeRules(
                winBy: .scoreMost,
                series: .singleRound,
                roundDurationSec: userTimeAttackDuration ?? 60,
                livesPerPlayer: globalOneHit ? nil : 1,
                oneHit: globalOneHit ? true : false,
                scoring: ScoringRules(gateScore: 1, collisionPenalty: 0, bonusOnStreak: 0),
                spawn: SpawnCurve(startSpawnInterval: 1.0, endSpawnInterval: 1.0, maxSimultaneous: 9),
                botEnabled: false,
                allowTies: true
            )

        case .timeAttackDuel:
            return ModeRules(
                winBy: .scoreMost,
                series: .bestOf(3),
                roundDurationSec: userTimeAttackDuration ?? 60,
                livesPerPlayer: globalOneHit ? nil : 1,
                oneHit: globalOneHit ? true : false,
                scoring: ScoringRules(gateScore: 1, collisionPenalty: 0, bonusOnStreak: 0),
                spawn: SpawnCurve(startSpawnInterval: 1.0, endSpawnInterval: 1.0, maxSimultaneous: 9),
                botEnabled: false,
                allowTies: true
            )

        case .suddenDeath:
            return ModeRules(
                winBy: .surviveLast,
                series: .bestOf(5),
                roundDurationSec: 20,
                livesPerPlayer: nil,
                oneHit: true, // forced on; global toggle ignored
                scoring: ScoringRules(),
                spawn: SpawnCurve(startSpawnInterval: 0.8, endSpawnInterval: 0.8, maxSimultaneous: 10),
                botEnabled: false,
                allowTies: false
            )
        }
    }
}
