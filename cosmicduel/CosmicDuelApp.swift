import SwiftUI

@main
struct CosmicDuelApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var match = MatchState()
    @Environment(\.scenePhase) private var scenePhase

    
    
    
    var body: some Scene {
        WindowGroup {
           
                RootTabView()
                    .environmentObject(theme)
                    .environmentObject(match)
                    .background(ColorTokens.background.color.ignoresSafeArea())
                    .preferredColorScheme(theme.currentColorScheme)
                    .onChange(of: scenePhase) { newPhase in
                        switch newPhase {
                        case .active:
                            match.appDidBecomeActive()
                        case .inactive, .background:
                            match.appDidEnterBackground()
                        @unknown default:
                            break
                        }
                    }
                
                
                    .onAppear {
                                        
                        ReviewNudge.shared.schedule(after: 60)
                                 
                    }
                
                
            
        
            
        }
        
        
        
        
    }
}
