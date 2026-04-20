import SwiftUI

@main
struct Seizcare_watch_app_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var pipeline = DetectionPipelineManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("[Pipeline] Auto-starting seizure detection pipeline on launch...")
                    pipeline.start()
                }
                .environmentObject(pipeline)
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("[APP] App became active")
            case .background:
                print("[APP] App moved to background")
            default:
                break
            }
        }
    }
}
