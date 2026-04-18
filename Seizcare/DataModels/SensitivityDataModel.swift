//
//  SensitivityDataModel.swift
//  Seizcare
//

import Foundation
import SwiftUI
import Combine

// MARK: - SensitivityLevel Enum
enum SensitivityLevel: String, Codable {
    case low
    case medium
    case high
}

// MARK: - SensitivityDataModel
@MainActor
final class SensitivityDataModel: ObservableObject {

    static let shared = SensitivityDataModel()

    // In-memory cache — exposed for reactive UI binding
    @Published var currentSensitivity: SensitivityLevel = .medium
    private var isRefreshing = false

    private init() {}

    // MARK: - Refresh (async, Supabase → cache)
    /// Fetches the user's sensitivity preference from Supabase.
    /// If no preference exists, it defaults to `.medium` and inserts a new record to Supabase.
    func refreshSensitivity() async {
        guard let userId = UserDataModel.shared.getCurrentUser()?.id else { return }
        if isRefreshing { return }
        
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            if let dto = try await SupabaseService.shared.fetchSensitivity(userId: userId) {
                if let level = SensitivityLevel(rawValue: dto.sensitivityLevel) {
                    self.currentSensitivity = level
                    print("✅ [Sensitivity] Successfully fetched preference: \(level.rawValue)")
                }
            } else {
                // No record — upsert default (.medium)
                let defaultLevel: SensitivityLevel = .medium
                self.currentSensitivity = defaultLevel
                let dto = SensitivityDTO(userId: userId, sensitivityLevel: defaultLevel.rawValue)
                try await SupabaseService.shared.upsertSensitivity(dto: dto)
            }
            
            // Push updated setting to Apple Watch
            WatchConnectivityManager.shared.sendSensitivityToWatch(currentSensitivity.rawValue)
            
        } catch where error is CancellationError {
            // Silently ignore task cancellations
        } catch {
            print("⚠️ [SensitivityDataModel] refreshSensitivity failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Accessors
    /// Returns the currently cached sensitivity level.
    func getCurrentSensitivity() -> SensitivityLevel {
        return currentSensitivity
    }

    // MARK: - Set Preference
    /// Updates the in-memory cache and pushes the change to Supabase via upsert.
    func setSensitivity(level: SensitivityLevel) {
        currentSensitivity = level
        
        guard let userId = UserDataModel.shared.getCurrentUser()?.id else {
            print("❌ [Sensitivity] No current user — cannot write to Supabase.")
            return
        }
        
        Task {
            do {
                let dto = SensitivityDTO(userId: userId, sensitivityLevel: level.rawValue)
                try await SupabaseService.shared.upsertSensitivity(dto: dto)
                print("✅ [Sensitivity] Saved '\(level.rawValue)' for user \(userId)")
            } catch {
                print("❌ [Sensitivity] Write failed: \(error.localizedDescription)")
            }
        }
        
        // Push the update to the Apple Watch
        WatchConnectivityManager.shared.sendSensitivityToWatch(level.rawValue)
    }
    
    /// Called by WatchConnectivityManager when a new sensitivity level is received from the Watch.
    /// Updates local state and pushes back to Supabase, but does NOT re-push to Watch.
    func applySyncUpdate(levelString: String) {
        guard let level = SensitivityLevel(rawValue: levelString.lowercased()) else {
            print("⚠️ [Sensitivity] Received invalid sync level: \(levelString)")
            return
        }
        
        // Prevent redundant updates
        guard level != currentSensitivity else { return }
        
        print("🔄 [Sensitivity] Applying sync update from Watch: \(level.rawValue)")
        self.currentSensitivity = level
        
        // Persistence to Supabase
        guard let userId = UserDataModel.shared.getCurrentUser()?.id else { return }
        Task {
            do {
                let dto = SensitivityDTO(userId: userId, sensitivityLevel: level.rawValue)
                try await SupabaseService.shared.upsertSensitivity(dto: dto)
                print("✅ [Sensitivity] Synced Watch update saved to Supabase")
            } catch {
                print("❌ [Sensitivity] Failed to save Watch sync to Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Reset
    /// Resets the local sensitivity state to default. Called during logout.
    func resetToDefault() {
        currentSensitivity = .medium
        print("🔄 [Sensitivity] Reset to default (.medium)")
    }
}
