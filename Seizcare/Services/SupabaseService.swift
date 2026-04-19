//
//  SupabaseService.swift
//  Seizcare
//
//  Created by GS Agrawal on 11/03/26.
//

import Foundation
import Supabase
import Auth

// MARK: - SupabaseService

final class SupabaseService {
    
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://ydbudbenyxrfwdzumxbu.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkYnVkYmVueXhyZndkenVteGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQzMzcsImV4cCI6MjA5MTkyMDMzN30.ydIKpaJGRWNeusSN-Aa4LGy8Hh_evmILnv9Z0ZRs4mw"
        )
    }
    
    // MARK: - Auth
    
    /// Sign in with email and password. Returns the Supabase user UUID on success.
    func signIn(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(email: email, password: password)
        return session.user.id
    }
    
    /// Sign up with email and password. Returns the Supabase user on success.
    func signUp(email: String, password: String) async throws -> Auth.User {
        let response = try await client.auth.signUp(email: email, password: password)
        // In Supabase Swift SDK v2, AuthResponse.user is non-optional
        return response.user
    }
    
    /// Sign out the current user.
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    /// Completely deletes the user's account by calling the Supabase Edge Function
    func deleteAccount() async throws {
        print("🟢 [SupabaseService] START ACCOUNT DELETION")
        
        // 1. Get current session and throw if nil
        guard let _ = try? await client.auth.session else {
            throw SupabaseServiceError.authFailed("User not logged in")
        }
        
        // 2. Explicitly refresh the session to ensure not expired
        let freshSession = try await client.auth.refreshSession()
        let accessToken = freshSession.accessToken
        let userId = freshSession.user.id
        
        print("✅ Session refreshed. User ID: \(userId)")

        // 3. Build POST request to the explicit URL
        guard let url = URL(string: "https://ydbudbenyxrfwdzumxbu.supabase.co/functions/v1/delete-user") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 4. Headers: Pass anonKey as Authorization to satisfy Kong's API gateway,
        // and pass the actual user's ES256 token in a custom header to bypass Kong's rejection.
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkYnVkYmVueXhyZndkenVteGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQzMzcsImV4cCI6MjA5MTkyMDMzN30.ydIKpaJGRWNeusSN-Aa4LGy8Hh_evmILnv9Z0ZRs4mw"
        
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey") 
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "x-user-token")
        
        // 5. Build Payload
        let payload = ["user_id": userId.uuidString.lowercased()]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ [SupabaseService] ERROR: Could not serialize payload")
            throw URLError(.cannotParseResponse)
        }
        request.httpBody = httpBody
        
        print("➡️ Request Headers:")
        if let authHeader = request.allHTTPHeaderFields?["Authorization"] {
            // Mask the token to keep console clean
            let maskedAuth = String(authHeader.prefix(20)) + "...[MASKED]..." + String(authHeader.suffix(10))
            print("   Authorization: \(maskedAuth)")
        }
        print("   apikey: [MASKED]")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [SupabaseService] ERROR: Invalid response object")
                throw URLError(.badServerResponse)
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "Unreadable body"
            print("⬅️ Response Status Code: \(httpResponse.statusCode)")
            print("⬅️ Response Body JSON: \n\(responseBody)\n========================================")
            
            if !(200...299).contains(httpResponse.statusCode) {
                throw SupabaseServiceError.authFailed("HTTP \(httpResponse.statusCode) - \(responseBody)")
            }
            
        } catch {
            print("❌ [SupabaseService] CATCH BLOCK ERROR: \(error.localizedDescription)")
            print("========================================")
            throw error
        }
    }
    
    // MARK: - Password Reset (OTP)
    
    /// Ask Supabase to send an 8-digit OTP to the given email for password reset.
    func sendPasswordResetOTP(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    /// Verifies the OTP code sent to the email address.
    func verifyPasswordResetOTP(email: String, otp: String) async throws {
        try await client.auth.verifyOTP(email: email, token: otp, type: .recovery)
    }
    
    /// Updates the user's password once an active session (via verified OTP) is established.
    func updateUserPassword(newPassword: String) async throws {
        let attributes = UserAttributes(password: newPassword)
        _ = try await client.auth.update(user: attributes)
    }
    
    /// Returns the currently authenticated user's UUID, or nil if not logged in.
    func currentUserId() async -> UUID? {
        return try? await client.auth.user().id
    }
    
    // MARK: - Sign Up (OTP)
    
    /// Verifies the OTP code from initial sign-up (Supabase uses type `.signup`).
    @discardableResult
    func verifySignUpOTP(email: String, otp: String) async throws -> UUID {
        let session = try await client.auth.verifyOTP(email: email, token: otp, type: .signup)
        return session.user.id
    }
    
    /// Verifies an OTP that was sent via `signInWithOTP` (resend path). Supabase uses type `.email`.
    @discardableResult
    func verifyEmailOTP(email: String, otp: String) async throws -> UUID {
        let session = try await client.auth.verifyOTP(email: email, token: otp, type: .email)
        return session.user.id
    }
    
    /// Resends the signup OTP for users whose email is already registered but unverified.
    /// Uses signInWithOTP which reliably sends a numeric OTP code.
    func resendSignUpOTP(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email,
            shouldCreateUser: false
        )
    }
    
    // MARK: - Users Table
    
    func fetchUsers() async throws -> [UserDTO] {
        let rows: [UserDTO] = try await client
            .from("users")
            .select()
            .execute()
            .value
        return rows
    }
    
    func fetchUser(id: UUID) async throws -> UserDTO? {
        // First, fetch raw data so we can log exactly what Supabase returned
        let response = try await client
            .from("users")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .limit(1)
            .execute()
        
        if let raw = String(data: response.data, encoding: .utf8) {
            print("[fetchUser] raw JSON:", raw)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([UserDTO].self, from: response.data)
        return rows.first
    }
    
    func insertUser(_ dto: UserDTO) async throws {
        try await client
            .from("users")
            .insert(dto)
            .execute()
    }
    
    func updateUser(_ dto: UserDTO) async throws {
        try await client
            .from("users")
            .update(dto)
            .eq("id", value: dto.id.uuidString)
            .execute()
    }
    
    // MARK: - Avatar Storage
    
    /// Uploads JPEG data to the `avatars` bucket and returns the public URL.
    /// Upserts so repeated calls simply replace the previous photo.
    /// A `?v=<timestamp>` is appended to bust the Supabase CDN cache on every upload
    /// so re-uploads of the same user always serve fresh content.
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString.lowercased()).jpg"
        
        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        // Append version timestamp — forces CDN cache-miss so second/third uploads are seen immediately.
        // This URL with the version is saved to the DB so every load fetches the post-upload image.
        let versionedURL = publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
        print("✅ [SupabaseService] Avatar uploaded — \(versionedURL)")
        return versionedURL
    }
    
    /// Patches only the `avatar_url` column for the given user row.
    func updateUserAvatar(userId: UUID, url: String) async throws {
        struct AvatarPatch: Encodable {
            let avatar_url: String
        }
        try await client
            .from("users")
            .update(AvatarPatch(avatar_url: url))
            .eq("id", value: userId.uuidString.lowercased())
            .execute()
    }
    
    // MARK: - Emergency Contacts
    
    func fetchContacts(userId: UUID) async throws -> [EmergencyContactDTO] {
        let rows: [EmergencyContactDTO] = try await client
            .from("emergency_contacts")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
            .value
        return rows
    }
    
    func insertContact(_ dto: EmergencyContactDTO) async throws {
        try await client
            .from("emergency_contacts")
            .insert(dto)
            .execute()
    }
    
    func deleteContact(id: UUID) async throws {
        try await client
            .from("emergency_contacts")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
    
    // MARK: - Sensitivity
    
    /// Fetch the current sensitivity record for a user.
    func fetchSensitivity(userId: UUID) async throws -> SensitivityDTO? {
        let response = try await client
            .from("user_sensitivity")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .limit(1)
            .execute()
        
        let decoder = JSONDecoder()
        let rows = try decoder.decode([SensitivityDTO].self, from: response.data)
        return rows.first
    }
    
    /// Insert or update the sensitivity record for a user.
    func upsertSensitivity(dto: SensitivityDTO) async throws {
        try await client
            .from("user_sensitivity")
            .upsert(dto, onConflict: "user_id")
            .execute()
    }
    
    // MARK: - Seizure Records
    
    /// Fetch all seizure records for the current user, ordered newest first.
    func fetchSeizureRecords(userId: UUID) async throws -> [SeizureRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try await client
            .from("seizure_records")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("start_time", ascending: false)
            .execute()
        
        return try decoder.decode([SeizureRecord].self, from: response.data)
    }
    
    /// Insert a new seizure record.
    func insertSeizureRecord(_ record: SeizureRecord) async throws {
        let dto = SeizureRecordDTO(from: record)
        try await client
            .from("seizure_records")
            .insert(dto)
            .execute()
    }
    
    /// Update an existing seizure record (matched by id).
    func updateSeizureRecord(_ record: SeizureRecord) async throws {
        let dto = SeizureRecordDTO(from: record)
        try await client
            .from("seizure_records")
            .update(dto)
            .eq("id", value: record.id.uuidString.lowercased())
            .execute()
    }
    
    /// Delete a seizure record by id.
    func deleteSeizureRecord(id: UUID) async throws {
        try await client
            .from("seizure_records")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
    
    // MARK: - SeizureRecord Write DTO
    
    /// A dedicated Encodable struct for writing seizure records to Supabase.
    /// Keeps the domain model clean while satisfying the SDK's Encodable requirement.
    private struct SeizureRecordDTO: Encodable {
        let id: String
        let user_id: String
        let entry_type: String
        let start_time: String
        let end_time: String
        let severity_type: String
        let triggers: [String]
        let location: String?
        let notes: String?
        
        init(from record: SeizureRecord) {
            let fmt = ISO8601DateFormatter()
            self.id            = record.id.uuidString.lowercased()
            self.user_id       = record.userId.uuidString.lowercased()
            self.entry_type    = record.entryType.rawValue
            self.start_time    = fmt.string(from: record.startTime)
            self.end_time      = fmt.string(from: record.endTime)
            self.severity_type = record.type.rawValue
            self.triggers      = record.triggers.map { $0.rawValue }
            self.location      = record.location
            self.notes         = record.notes
        }
    }
    
    // MARK: - Sleep Records
    
    /// Fetch sleep records for the current user.
    func fetchSleepRecords(userId: UUID) async throws -> [SleepRecord] {
        let decoder = JSONDecoder()
        // Supabase returns `sleep_date` as a plain date string (no time), use custom strategy
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        let response = try await client
            .from("sleep_records")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("sleep_date", ascending: false)
            .limit(90)
            .execute()
        
        return try decoder.decode([SleepRecord].self, from: response.data)
    }
    
    // MARK: - Heart Rate Samples
    
    /// Fetch heart rate samples linked to a specific seizure record.
    func fetchHeartRateSamples(recordId: UUID) async throws -> [HeartRateSample] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try await client
            .from("heart_rate_samples")
            .select()
            .eq("record_id", value: recordId.uuidString.lowercased())
            .order("timestamp", ascending: true)
            .execute()
        
        return try decoder.decode([HeartRateSample].self, from: response.data)
    }
    
    // MARK: - Notifications
    
    /// Fetch all notifications for the current user, ordered newest first.
    func fetchNotifications(userId: UUID) async throws -> [AppNotification] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try await client
            .from("app_notifications")
            .select()
            .eq("user_id", value: userId.uuidString.lowercased())
            .order("event_date", ascending: false)
            .execute()
        
        return try decoder.decode([AppNotification].self, from: response.data)
    }
    
    /// Mark a single notification as read.
    func markNotificationRead(id: UUID) async throws {
        struct ReadPatch: Encodable { let is_read: Bool }
        try await client
            .from("app_notifications")
            .update(ReadPatch(is_read: true))
            .eq("id", value: id.uuidString.lowercased())
            .execute()
    }
}

    
    // MARK: - SupabaseServiceError
    
    enum SupabaseServiceError: Error, LocalizedError {
        case authFailed(String)
        case notFound(String)
        
        var errorDescription: String? {
            switch self {
            case .authFailed(let msg): return "Auth failed: \(msg)"
            case .notFound(let msg):   return "Not found: \(msg)"
            }
        }
    }
    
    // MARK: - DTOs (snake_case → Supabase column mapping)
    
    // Each DTO uses CodingKeys to map Swift camelCase to Supabase snake_case column names.
    // They are separate from the app-level model structs to keep the persistence concern isolated.
    
    struct UserDTO: Codable {
        let id: UUID
        let fullName: String?
        let email: String?
        let contactNumber: String?
        let createdAt: String?   // Extra column returned by Supabase — absorb so decode never fails
        let avatarUrl: String?   // Supabase Storage public URL for profile photo
        
        enum CodingKeys: String, CodingKey {
            case id
            case fullName      = "full_name"
            case email
            case contactNumber = "contact_number"
            case createdAt     = "created_at"
            case avatarUrl     = "avatar_url"
        }
        
        // Convert domain model → DTO (for INSERT / UPDATE)
        init(from user: User) {
            self.id            = user.id
            self.fullName      = user.fullName
            self.email         = user.email
            self.contactNumber = user.contactNumber
            self.createdAt     = nil
            self.avatarUrl     = user.avatarUrl
        }
        
        // Convert DTO → domain model
        func toDomain() -> User {
            return User(
                id:            id,
                fullName:      fullName      ?? "",
                email:         email         ?? "",
                contactNumber: contactNumber ?? "",
                password:      "",
                avatarUrl:     avatarUrl
            )
        }
    }

struct EmergencyContactDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let contactNumber: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case contactNumber = "contact_number"
    }

    init(from contact: EmergencyContact) {
        self.id = contact.id
        self.userId = contact.userId
        self.name = contact.name
        self.contactNumber = contact.contactNumber
    }

    func toDomain() -> EmergencyContact {
        return EmergencyContact(id: id, userId: userId, name: name, contactNumber: contactNumber)
    }
}

struct SensitivityDTO: Codable {
    let userId: UUID
    let sensitivityLevel: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sensitivityLevel = "sensitivity_level"
    }
}
