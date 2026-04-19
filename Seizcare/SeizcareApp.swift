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
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        }
    }
}
