//
//  LanguageManager.swift
//  Seizcare
//

import SwiftUI
import Combine

struct AppLanguage: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let nativeName: String
    let englishName: String
}

@MainActor
class LanguageManager: ObservableObject {
    @Published var currentLanguage: String = UserDefaults.standard.string(forKey: "app_language") ?? "en" {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
        }
    }

    let languages = [
        AppLanguage(code: "en", nativeName: "English", englishName: "English"),
        AppLanguage(code: "hi", nativeName: "हिंदी", englishName: "Hindi"),
        AppLanguage(code: "bn", nativeName: "বাংলা", englishName: "Bengali"),
        AppLanguage(code: "te", nativeName: "తెలుగు", englishName: "Telugu"),
        AppLanguage(code: "mr", nativeName: "मराठी", englishName: "Marathi"),
        AppLanguage(code: "ta", nativeName: "தமிழ்", englishName: "Tamil")
    ]

    func setLanguage(_ code: String) {
        currentLanguage = code
    }
}

// We keep this for non-SwiftUI places, but we'll use standard Text() for reactivity in views
extension String {
    var localized: String {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
