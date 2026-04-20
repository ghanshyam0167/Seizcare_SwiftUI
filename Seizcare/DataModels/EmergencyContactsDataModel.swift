//
//  EmergencyContactsDataModel.swift
//  Seizcare

import Foundation
import SwiftUI
import Combine

//  EmergencyContact Model
struct EmergencyContact: Equatable, Codable {
    let id: UUID
    let userId: UUID
    var name: String
    var contactNumber: String

    /// Convenience init for creating new contacts (generates a new UUID).
    init(userId: UUID, name: String, contactNumber: String) {
        self.id            = UUID()
        self.userId        = userId
        self.name          = name
        self.contactNumber = contactNumber
    }

    /// Full memberwise init used by DTO → domain conversion.
    init(id: UUID, userId: UUID, name: String, contactNumber: String) {
        self.id            = id
        self.userId        = userId
        self.name          = name
        self.contactNumber = contactNumber
    }

    static func == (lhs: EmergencyContact, rhs: EmergencyContact) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Emergency Contact Data Model
@MainActor
class EmergencyContactDataModel: ObservableObject {

    static let shared = EmergencyContactDataModel()

    @Published private var cachedContacts: [EmergencyContact] = []
    @Published private(set) var isRefreshing = false

    private init() {}

    // MARK: - Public Refresh (async, call from ViewControllers)

    /// Fetches contacts for the current user from Supabase and updates the cache.
    func refreshContacts() async {
        guard let userId = UserDataModel.shared.getCurrentUser()?.id else {
            print("⚠️ [EmergencyContactDataModel] refreshContacts aborted: No user logged in.")
            return
        }
        
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        print("📲 [EmergencyContactDataModel] Fetching contacts for userId: \(userId.uuidString.lowercased())")
        do {
            let dtos = try await SupabaseService.shared.fetchContacts(userId: userId)
            cachedContacts = dtos.map { $0.toDomain() }
            print("✅ [EmergencyContactDataModel] Successfully fetched \(cachedContacts.count) contacts.")
        } catch where error is CancellationError {
            // Standard SwiftUI task cancellation, ignore
        } catch {
            print("⚠️ [EmergencyContactDataModel] refreshContacts failed:", error.localizedDescription)
        }
    }

    //  Public Methods

    /// Get all contacts (for debugging/admin)
    func getAllContacts() -> [EmergencyContact] {
        return cachedContacts
    }

    // ─── DEMO BYPASS CONSTANT ───
    private let demoUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Returns contacts for the currently logged-in user from the local cache.
    func getContactsForCurrentUser() -> [EmergencyContact] {
        let userId = UserDataModel.shared.getCurrentUser()?.id ?? demoUserId
        let filtered = cachedContacts.filter { $0.userId == userId }
        return filtered
    }

    /// Adds a new contact for the currently logged-in user.
    func addContact(name: String, contactNumber: String) {
        let userId = UserDataModel.shared.getCurrentUser()?.id ?? demoUserId
        let formattedNumber = EmergencyContactDataModel.formatIndianNumber(contactNumber)
        
        // Prevent duplicates
        if cachedContacts.contains(where: { $0.userId == userId && $0.contactNumber == formattedNumber }) {
            print("⚠️ [EmergencyContactDataModel] Contact already exists.")
            return
        }
        
        let newContact = EmergencyContact(
            userId: userId,
            name: name,
            contactNumber: formattedNumber
        )
        cachedContacts.append(newContact)
        print("📲 [EmergencyContactDataModel] Adding contact: \(name) (\(formattedNumber))")
        
        // Only attempt backend sync if a real user exists
        if UserDataModel.shared.getCurrentUser() != nil {
            Task {
                do {
                    try await SupabaseService.shared.insertContact(EmergencyContactDTO(from: newContact))
                    print("✅ [EmergencyContactDataModel] Contact successfully saved to Supabase.")
                } catch {
                    print("⚠️ [EmergencyContactDataModel] addContact failed:", error.localizedDescription)
                }
            }
        } else {
            print("⚠️ [DEMO MODE] Added contact locally, skipping Supabase sync.")
        }
    }

    /// Normalizes numbers to +91XXXXXXXXXX format
    private static func formatIndianNumber(_ number: String) -> String {
        // Strip everything but digits
        let digits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if digits.count == 10 {
            return "+91\(digits)"
        } else if digits.count == 11 && digits.hasPrefix("0") {
            return "+91\(digits.dropFirst())"
        } else if digits.count == 12 && digits.hasPrefix("91") {
            return "+\(digits)"
        } else if digits.count > 10 && digits.hasSuffix(digits.suffix(10)) {
            // Likely already has a country code, just ensure + is there
            return "+\(digits)"
        }
        
        return number // Fallback to raw if unrecognizable
    }

    /// Deletes a contact by ID.
    func deleteContact(id: UUID) {
        cachedContacts.removeAll { $0.id == id }
        Task {
            do {
                try await SupabaseService.shared.deleteContact(id: id)
            } catch {
                print("⚠️ [EmergencyContactDataModel] deleteContact failed:", error.localizedDescription)
            }
        }
    }

    /// Clears the local cache of contacts. Called during logout.
    func clearCache() {
        cachedContacts = []
        print("🔄 [EmergencyContactDataModel] Cache cleared.")
    }
}
