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
final class SensitivityDataModel: ObservableObject {

    static let shared = SensitivityDataModel()

    // In-memory cache — exposed for reactive UI binding
    @Published var currentSensitivity: SensitivityLevel = .medium

    private init() {}

    // MARK: - Refresh (async, Supabase → cache)
    /// Fetches the user's sensitivity preference from Supabase.
    /// If no preference exists, it defaults to `.medium` and inserts a new record to Supabase.
    func refreshSensitivity() async {
        guard let userId = UserDataModel.shared.getCurrentUser()?.id else { return }

        do {
            if let dto = try await SupabaseService.shared.fetchSensitivity(userId: userId) {
                // Record found — update cache
                if let level = SensitivityLevel(rawValue: dto.sensitivityLevel) {
                    await MainActor.run { currentSensitivity = level }
                }
            } else {
                // No record — upsert default (.medium)
                let defaultLevel: SensitivityLevel = .medium
                await MainActor.run { currentSensitivity = defaultLevel }
                let dto = SensitivityDTO(userId: userId, sensitivityLevel: defaultLevel.rawValue)
                try await SupabaseService.shared.upsertSensitivity(dto: dto)
            }
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
    }
}
