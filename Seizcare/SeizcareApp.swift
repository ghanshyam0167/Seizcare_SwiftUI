//
//  SeizcareApp.swift
//  Seizcare
//
//  Created by GS Agrawal on 30/03/26.
//

import SwiftUI
import Combine

@main
struct SeizcareApp: App {
    @StateObject var languageManager = LanguageManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register background processing for offline sensor log uploads.
        SensorLogBackgroundTasks.register()
        // Activate WatchConnectivity early so background-delivered Watch batches are received.
        _ = WatchConnectivityManager.shared
    }
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
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
                SensorLogBackgroundTasks.schedule()
            default:
                break
            }
        }
    }
}
