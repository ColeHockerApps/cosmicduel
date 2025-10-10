import SwiftUI
import SpriteKit

struct GameView: View {
    @EnvironmentObject private var match: MatchState
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var scene: DuelScene?
    @State private var containerSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // SpriteKit layer (занимает весь экран под safe area)
                if let scene {
                    SpriteView(scene: scene,
                               preferredFramesPerSecond: GameConstants.UI.preferredFPS)
                        .ignoresSafeArea() // только рендер игры игнорит safe area
                } else {
                    // Create scene when size is known
                    Color.black.opacity(0.001)
                        .onAppear {
                            containerSize = geo.size
                            rebuildScene()
                        }
                        .ignoresSafeArea()
                }

                // HUD overlay — БЕЗ ignoresSafeArea: уважает верхний safe area
                HUDOverlay(
                    onBack: {
                        Haptics.shared.selectionChanged()
                        dismiss()
                    },
                    onRematch: {
                        Haptics.shared.selectionChanged()
                        match.rematch()
                        scene?.resetRoundForRematch()
                    },
                    onNextRound: {
                        Haptics.shared.selectionChanged()
                        match.nextRoundOrEndSeries()
                        scene?.resetRoundForRematch()
                    }
                )
            }
            .preferredColorScheme(theme.currentColorScheme)
            .toolbar(.hidden, for: .tabBar) // скрыть таббар в игре
            .onChange(of: geo.size) { newSize in
                containerSize = newSize
                scene?.size = newSize
            }
            .onChange(of: match.mode) { _ in
                rebuildScene()
            }
            .onChange(of: match.rules) { _ in
                // soft restart when rules change mid-match
                scene?.resetRoundForRematch()
            }
            .onChange(of: match.phase) { newPhase in
                if newPhase == .playing {
                    // ensure scene matches current size
                    scene?.size = geo.size
                }
            }
            .onAppear {
                if scene == nil {
                    containerSize = geo.size
                    rebuildScene()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func rebuildScene() {
        let size = containerSize == .zero ? UIScreen.main.bounds.size : containerSize
        let newScene = DuelScene(size: size, match: match)
        newScene.scaleMode = .resizeFill
        self.scene = newScene
    }
}
