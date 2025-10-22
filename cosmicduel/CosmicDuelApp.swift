import SwiftUI

@main
struct CosmicDuelApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var match = MatchState()
    @Environment(\.scenePhase) private var scenePhase

    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if OrientationGate.allowAll {
                return [.portrait, .landscapeLeft, .landscapeRight]
            } else {
                return [.portrait]
            }
        }
    }
    init() {

        NotificationCenter.default.post(name: Notification.Name("art.icon.loading.start"), object: nil)
        IconSettings.shared.attach()

        

    }
    
    
    var body: some Scene {
        WindowGroup {
            TabSettingsView{
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
            
            .onAppear {
                OrientationGate.allowAll = false
            }
            
        }
        
        
        
        
    }
}
