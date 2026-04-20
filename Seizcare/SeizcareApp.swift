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
    
    // Notification delegate to handle foreground sound
    private let notificationDelegate = NotificationDelegate()
    
    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
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
            default:
                break
            }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Force the notification to show sound and alert even in the foreground
        completionHandler([.banner, .sound, .badge, .list])
    }
}
