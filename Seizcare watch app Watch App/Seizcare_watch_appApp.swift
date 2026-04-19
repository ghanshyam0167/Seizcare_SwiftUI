//
//  Seizcare_watch_appApp.swift
//  Seizcare watch app Watch App
//
//  Created by Diya Sharma on 18/04/26.
//

import SwiftUI

@main
struct Seizcare_watch_app_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
