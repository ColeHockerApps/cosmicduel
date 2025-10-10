import CoreGraphics
import UIKit

// MARK: - Rocket paint model (top → bottom gradient)
struct RocketPaint: Equatable {
    let top: UIColor
    let bottom: UIColor
}

/// Centralized constants for gameplay tuning and visuals.
enum GameConstants {

    // MARK: - World / Physics
    enum Physics {
        /// Base gravity for the scene (points/s²). SpriteKit uses "meters", but we'll treat as points.
        static let gravity = CGVector(dx: 0.0, dy: -3.8)

        /// World edge thickness used for edgeLoop convenience (visual doesn't matter, just collisions).
        static let worldEdgeInset: CGFloat = 0.0

        /// Max vertical velocity clamp for rocket bodies (prevents uncontrollable speeds).
        static let maxVelocityY: CGFloat = 720.0
        static let minVelocityY: CGFloat = -880.0

        /// Restitution/friction for static obstacles.
        static let obstacleFriction: CGFloat = 0.0
        static let obstacleRestitution: CGFloat = 0.0
        static let obstacleLinearDamping: CGFloat = 0.0
        static let obstacleAngularDamping: CGFloat = 0.0
    }

    // MARK: - Rocket
    enum Rocket {
        /// Name of raster asset used for both players (white silhouette).
        static let spriteName = "rocket_unit"

        /// Visual size of the rocket body (without flame).
        static let bodySize = CGSize(width: 45, height: 65) // 30-50
        static let bodyCornerRadius: CGFloat = 6

        /// Physics body size (slightly smaller than visuals for fair collisions).
        static let physicsSize = CGSize(width: 40, height: 55) // 28-48

        /// Thrust impulse when player taps/holds (tuned for our gravity).
        static let thrustImpulse = CGVector(dx: 0, dy: 7)

        /// Rotation angles applied during flight.
        static let tiltUp: CGFloat   = .pi / 16      // ~11.25°
        static let tiltDown: CGFloat = -.pi / 12     // ~-15°
        static let tiltDurationUp:  TimeInterval = 0.10
        static let tiltDurationDown: TimeInterval = 0.30

        /// Horizontal dash (short strafe burst) and cooldown.
        static let dashImpulseX: CGFloat = 180.0
        static let dashCooldown: TimeInterval = 0.70
        static let dashDurationVisual: TimeInterval = 0.08 // slight visual nudge

        /// Safe margin from screen edges on spawn.
        static let spawnXFraction: CGFloat = 0.25    // left player at 25% width; right player mirrored
        static let spawnYOffset: CGFloat = 0.0       // start at vertical center
    }

    // MARK: - Controls
    enum Controls {
        /// Minimum press time to consider as "hold"; shorter taps still apply thrust.
        static let holdThreshold: TimeInterval = 0.07

        /// Dead-zone to ignore very short horizontal swipes (points).
        static let swipeDeadZone: CGFloat = 12.0

        /// Max swipe tracking time (sec) to convert to a dash.
        static let swipeMaxWindow: TimeInterval = 0.25
    }

    // MARK: - Obstacles
    enum Obstacles {
        /// Base horizontal velocity (points/s). Direction ±; scene applies randomness.
        static let baseDriftSpeed: CGFloat = 150.0
        static let driftRandomness: CGFloat = 24.0  // ± random addition

        /// Asteroid sizes.
        static let asteroidMinSize = CGSize(width: 34, height: 34)
        static let asteroidMaxSize = CGSize(width: 92, height: 92)

        /// Mine (small) size and explosion knockback.
        static let mineSize = CGSize(width: 22, height: 22)
        static let mineKnockback = CGVector(dx: 0, dy: 220) // mild vertical shove
        static let mineAngularNudge: CGFloat = .pi / 10

        /// Gate for scoring (Time Attack). Thin vertical line the rocket can pass through.
        static let gateWidth: CGFloat = 2.0
        static let gateOffsetFromObstacleX: CGFloat = 15.0

        /// Spawn margins (off-screen creation point).
        static let spawnOffsetX: CGFloat = 40.0

        /// Rotation for asteroids.
        static let asteroidAngularVelocityRange: ClosedRange<CGFloat> = (-0.8 ... 0.8) // rad/s
    }

    // MARK: - Spawn / Difficulty
    enum Spawn {
        /// Hard cap to avoid runaway node counts (scene should also respect ModeRules.spawn.maxSimultaneous).
        static let absoluteMaxSimultaneous: Int = 16

        /// Minimum distance between freshly spawned obstacles to avoid unfair overlaps (points).
        static let minSeparation: CGFloat = 80.0

        /// Minimum vertical gap between paired obstacles (when forming tunnels). Affects survivability.
        static let minVerticalGap: CGFloat = 160.0
        static let maxVerticalGap: CGFloat = 210.0

        /// Random vertical padding from screen edges when placing tunnels.
        static let verticalSafeMargin: CGFloat = 120.0
    }

    // MARK: - Scoring
    enum Scoring {
        /// Combo window for streaks (if implemented by scene; 0 = disabled).
        static let streakWindow: TimeInterval = 0.0

        /// Visual bounce on score acquisition.
        static let scorePopScale: CGFloat = 1.15
        static let scorePopDuration: TimeInterval = 0.08
    }

    // MARK: - UI / HUD
    enum UI {
        /// Target fps for SpriteView.
        static let preferredFPS: Int = 60

        /// HUD paddings/margins.
        static let hudHorizontalPadding: CGFloat = 16.0
        static let hudVerticalPadding: CGFloat = 12.0

        /// Corner radius for HUD badges.
        static let hudCornerRadius: CGFloat = 12.0

        /// Pause overlay animation.
        static let pauseFadeDuration: TimeInterval = 0.15

        /// Result banner animation.
        static let resultSpringResponse: CGFloat = 0.30
        static let resultSpringDamping: CGFloat = 0.82
    }

    // MARK: - Z Positions (SpriteKit layering)
    enum Z {
        static let background: CGFloat = -10
        static let stars: CGFloat      = -5
        static let gates: CGFloat      = 0
        static let obstacles: CGFloat  = 1
        static let rockets: CGFloat    = 2
        static let effects: CGFloat    = 3
        static let hud: CGFloat        = 10
    }

    // MARK: - Colors (fallbacks; prefer ColorTokens where possible)
    enum Colors {
        /// UIColors for SpriteKit nodes (SwiftUI should use ColorTokens).
        static let skyDark  = UIColor(red: 0.06, green: 0.09, blue: 0.15, alpha: 1.0)  // deep space
        static let star     = UIColor(white: 1.0, alpha: 0.9)
        static let rocketA  = UIColor.systemBlue
        static let rocketB  = UIColor.systemOrange
        static let asteroidA = UIColor.systemTeal
        static let asteroidB = UIColor.systemBlue
        static let mine      = UIColor.systemRed
        static let flame     = UIColor.systemOrange
        static let gate      = UIColor.systemYellow

        /// Gradient palettes for rocket coloring (top → bottom).
        /// Используем белую текстуру `rocket_unit` и шейдер/тоновое умножение,
        /// чтобы красить её этими парами.
        static let rocketGradientPairs: [RocketPaint] = [
            .init(top: UIColor.systemTeal,        bottom: UIColor.systemBlue),
            .init(top: UIColor.systemPink,        bottom: UIColor.systemIndigo),
            .init(top: UIColor.systemOrange,      bottom: UIColor.systemRed),
            .init(top: UIColor.systemPurple,      bottom: UIColor.systemBlue),
            .init(top: UIColor.systemGreen,       bottom: UIColor.systemTeal),
            .init(top: UIColor.systemYellow,      bottom: UIColor.systemOrange),
            .init(top: UIColor.systemMint,        bottom: UIColor.systemGreen),
            .init(top: UIColor.systemCyan,        bottom: UIColor.systemIndigo),
            .init(top: UIColor(red:0.98,green:0.46,blue:0.36,alpha:1), bottom: UIColor(red:0.89,green:0.27,blue:0.52,alpha:1)), // coral → magenta
            .init(top: UIColor(red:0.41,green:0.82,blue:0.96,alpha:1), bottom: UIColor(red:0.26,green:0.56,blue:0.93,alpha:1))  // sky → azure
        ]
    }

    // MARK: - Misc / Seeds
    enum Misc {
        /// Whether to enable performance logging in release builds (keep false).
        static let performanceLoggingEnabled: Bool = false

        /// Starfield density (count per screen).
        static let starCount: Int = 90

        /// Starfield movement duration range (sec) for parallax effect.
        static let starDriftDurationRange: ClosedRange<TimeInterval> = 6.0 ... 12.0
    }
}
