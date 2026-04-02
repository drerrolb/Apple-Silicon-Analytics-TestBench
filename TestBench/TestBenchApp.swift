import SwiftUI

/// App entry point. Forces dark mode and starts ambient background music.
@main
struct TestBenchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    AudioManager.shared.startAmbientMusic()
                }
        }
    }
}
