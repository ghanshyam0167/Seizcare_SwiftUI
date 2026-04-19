import SwiftUI

@main
struct Seizcare_watch_app_Watch_AppApp: App {
    @StateObject private var pipeline = DetectionPipelineManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("[Pipeline] Auto-starting seizure detection pipeline on launch...")
                    pipeline.start()
                }
        }
    }
}
