import UIKit
import Combine

/// Centralized haptic engine for the app.
/// Use: Haptics.shared.impactLight(), Haptics.shared.success(), etc.
final class Haptics: ObservableObject {

    // MARK: - Singleton
    static let shared = Haptics()

    // MARK: - Public toggle (bind this to Settings later)
    @Published var isEnabled: Bool = true

    // MARK: - Generators
    private let notification = UINotificationFeedbackGenerator()
    private let selection   = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // iOS 13+ additional styles (soft/rigid) guarded at runtime
    private var impactSoft: UIImpactFeedbackGenerator?
    private var impactRigid: UIImpactFeedbackGenerator?

    // MARK: - Throttle
    private var lastFire: TimeInterval = 0
    private let minInterval: TimeInterval = 0.018 // ~18ms to avoid over-spam

    private init() {
        // Prepare additional styles when available
        if #available(iOS 13.0, *) {
            impactSoft = UIImpactFeedbackGenerator(style: .soft)
            impactRigid = UIImpactFeedbackGenerator(style: .rigid)
        }
        prepare() // warm up on creation
    }

    // MARK: - Lifecycle hooks
    /// Call on app become active to re-prepare engines (already safe to call anytime).
    func prepare() {
        guard supportsHaptics else { return }
        notification.prepare()
        selection.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft?.prepare()
        impactRigid?.prepare()
    }

    // MARK: - Capability
    private var supportsHaptics: Bool {
        // On hardware devices with Taptic Engine; Simulator returns false.
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil { return false }
        return true
    }

    // MARK: - Throttle helper
    private func canFire() -> Bool {
        let now = CACurrentMediaTime()
        if now - lastFire >= minInterval {
            lastFire = now
            return true
        }
        return false
    }

    // MARK: - Public API

    // General tap (use for thrust press, small UI taps)
    func tap() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    // Selection change (use for toggles, pickers)
    func selectionChanged() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    // Impacts (use for movement, dodges, gates)
    func impactLightFeedback() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    func impactMediumFeedback() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    func impactHeavyFeedback() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    /// Softer impact (iOS 13+). Falls back to .light if not available.
    func impactSoftFeedback() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        if let soft = impactSoft {
            soft.impactOccurred()
            soft.prepare()
        } else {
            impactLight.impactOccurred()
            impactLight.prepare()
        }
    }

    /// Rigid, snappier impact (iOS 13+). Falls back to .heavy if not available.
    func impactRigidFeedback() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        if let rigid = impactRigid {
            rigid.impactOccurred()
            rigid.prepare()
        } else {
            impactHeavy.impactOccurred()
            impactHeavy.prepare()
        }
    }

    // Notifications (use for success/fail round, KO, new high score)
    func success() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func warning() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    func error() {
        guard isEnabled, supportsHaptics, canFire() else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
