import SwiftUI
import Combine

/// Persistent user settings for Cosmic Duel.
final class GameSettings: ObservableObject {



    // MARK: - Ranges & defaults
    struct Limits {
        static let roundDurationRange   = 20...180      // seconds for Duel/Solo vs Bot
        static let timeAttackRange      = 30...180      // seconds for Time Attack
        static let defaultRoundDuration = 60
        static let defaultTimeAttack    = 60
    }

    // MARK: - Stored settings (AppStorage)
    @AppStorage("settings.hapticsEnabled") var storedHapticsEnabled: Bool = true {
        didSet { applyHapticsToggle() }
    }
    @AppStorage("settings.oneHitKOGlobal") var storedOneHitKOGlobal: Bool = false
    @AppStorage("settings.roundDurationSec") var storedRoundDurationSec: Int = Limits.defaultRoundDuration {
        didSet { clampRoundDuration() }
    }
    @AppStorage("settings.timeAttackDurationSec") var storedTimeAttackDurationSec: Int = Limits.defaultTimeAttack {
        didSet { clampTimeAttackDuration() }
    }
    

    // MARK: - Published mirrors for UI binding
    @Published private(set) var hapticsEnabled: Bool = true
    @Published private(set) var oneHitKOGlobal: Bool = false
    @Published private(set) var roundDurationSec: Int = Limits.defaultRoundDuration
    @Published private(set) var timeAttackDurationSec: Int = Limits.defaultTimeAttack

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        // Mirror stored values into published properties on launch
        hapticsEnabled = storedHapticsEnabled
        oneHitKOGlobal = storedOneHitKOGlobal
        roundDurationSec = Self.clamped(storedRoundDurationSec, in: Limits.roundDurationRange)
        timeAttackDurationSec = Self.clamped(storedTimeAttackDurationSec, in: Limits.timeAttackRange)

        // Ensure storage reflects clamped values
        storedRoundDurationSec = roundDurationSec
        storedTimeAttackDurationSec = timeAttackDurationSec

        // Apply side effects
        applyHapticsToggle()

        // Keep published & storage in sync when someone writes to published via setters below
        bindPublishers()
    }

    // MARK: - Public setters (for Views)
    func setHapticsEnabled(_ enabled: Bool) {
        storedHapticsEnabled = enabled
        hapticsEnabled = enabled
        applyHapticsToggle()
    }

    func setOneHitKOGlobal(_ on: Bool) {
        storedOneHitKOGlobal = on
        oneHitKOGlobal = on
    }

    func setRoundDurationSec(_ seconds: Int) {
        let clamped = Self.clamped(seconds, in: Limits.roundDurationRange)
        storedRoundDurationSec = clamped
        roundDurationSec = clamped
    }

    func setTimeAttackDurationSec(_ seconds: Int) {
        let clamped = Self.clamped(seconds, in: Limits.timeAttackRange)
        storedTimeAttackDurationSec = clamped
        timeAttackDurationSec = clamped
    }

    

    // MARK: - Helpers
    private static func clamped<T: Comparable>(_ value: T, in range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func clampRoundDuration() {
        let v = Self.clamped(storedRoundDurationSec, in: Limits.roundDurationRange)
        if v != storedRoundDurationSec { storedRoundDurationSec = v }
        roundDurationSec = v
    }

    private func clampTimeAttackDuration() {
        let v = Self.clamped(storedTimeAttackDurationSec, in: Limits.timeAttackRange)
        if v != storedTimeAttackDurationSec { storedTimeAttackDurationSec = v }
        timeAttackDurationSec = v
    }



    private func applyHapticsToggle() {
        Haptics.shared.isEnabled = storedHapticsEnabled
        hapticsEnabled = storedHapticsEnabled
        if storedHapticsEnabled {
            Haptics.shared.prepare()
        }
    }

    private func bindPublishers() {
        // If some View writes directly to @Published (via Bindings), mirror back to storage
        $hapticsEnabled
            .dropFirst()
            .sink { [weak self] v in self?.storedHapticsEnabled = v }
            .store(in: &cancellables)

        $oneHitKOGlobal
            .dropFirst()
            .sink { [weak self] v in self?.storedOneHitKOGlobal = v }
            .store(in: &cancellables)

        $roundDurationSec
            .dropFirst()
            .sink { [weak self] v in self?.storedRoundDurationSec = Self.clamped(v, in: Limits.roundDurationRange) }
            .store(in: &cancellables)

        $timeAttackDurationSec
            .dropFirst()
            .sink { [weak self] v in self?.storedTimeAttackDurationSec = Self.clamped(v, in: Limits.timeAttackRange) }
            .store(in: &cancellables)

       
    }

    // MARK: - Reset
    func resetToDefaults() {
        setHapticsEnabled(true)
        setOneHitKOGlobal(false)
        setRoundDurationSec(Limits.defaultRoundDuration)
        setTimeAttackDurationSec(Limits.defaultTimeAttack)
    }
}
