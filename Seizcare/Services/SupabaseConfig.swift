//
//  SupabaseConfig.swift
//  Seizcare
//

import Foundation

enum SupabaseConfig {
    // Fallbacks keep existing behavior even if Info.plist keys are not set yet.
    private static let fallbackURLString = "https://ydbudbenyxrfwdzumxbu.supabase.co"
    private static let fallbackAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkYnVkYmVueXhyZndkenVteGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQzMzcsImV4cCI6MjA5MTkyMDMzN30.ydIKpaJGRWNeusSN-Aa4LGy8Hh_evmILnv9Z0ZRs4mw"
    
    static var url: URL {
        let s = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: (s?.isEmpty == false ? s! : fallbackURLString))!
    }
    
    /// Supabase anon/public key (safe to embed in the client; do not use service role keys here).
    static var anonKey: String {
        let s = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false ? s! : fallbackAnonKey)
    }
}

