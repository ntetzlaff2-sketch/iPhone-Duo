import SwiftUI

@main
struct SnaptrapApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.dark)
        }
    }
}
