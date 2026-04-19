//
//  SeizcareApp.swift
//  Seizcare
//
//  Created by GS Agrawal on 30/03/26.
//

import SwiftUI

@main
struct SeizcareApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("[APP] App became active")
                // Core: Request notification permissions for background alarm fallback
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("[APP] Notification permission granted: \(granted)")
                }
            case .background:
                print("[APP] App moved to background")
            default:
                break
            }
        }
    }
}
