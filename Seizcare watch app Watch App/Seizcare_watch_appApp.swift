import SwiftUI

@main
struct Seizcare_watch_app_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var pipeline = DetectionPipelineManager()
    @StateObject private var demoManager = DemoDetectionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("[Pipeline] Auto-starting seizure detection pipeline on launch...")
                    pipeline.start()
                }
                .onChange(of: demoManager.isEnabled) { isEnabled in
                    if isEnabled {
                        print("[App] Demo Mode ENABLED. Stopping real pipeline.")
                        pipeline.stop()
                    } else {
                        print("[App] Demo Mode DISABLED. Restarting real pipeline.")
                        pipeline.start()
                    }
                }
                .environmentObject(pipeline)
                .environmentObject(demoManager)
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
