import SwiftUI

@main
struct PianoApp: App {
    var body: some Scene {
        WindowGroup {
            PianoView()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
        }
    }
}
