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
            supabaseURL: URL(string: "https://rewuxzcdgivbwmakwjtc.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJld3V4emNkZ2l2YndtYWt3anRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMTQ2OTEsImV4cCI6MjA4ODc5MDY5MX0.kk1Mq-O6SfQ60TZagcp202cGqNB08ywUPWgxlFdiXp4"
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
        
        // ✅ Get session correctly
        let session = try await client.auth.session
        
        let accessToken = session.accessToken
        
        guard let url = URL(string: "https://rewuxzcdgivbwmakwjtc.supabase.co/functions/v1/delete-user") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 🔥 ONLY THIS HEADER IS NEEDED
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Status:", httpResponse.statusCode)
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Server Error"
            print("❌ delete-user raw response:", errorMsg)
            throw SupabaseServiceError.authFailed("Failed to delete account (HTTP \(httpResponse.statusCode)): \(errorMsg)")
        }
        
        print("✅ Account deleted successfully.")
    }
    
    // MARK: - Password Reset (OTP)
    
    /// Ask Supabase to send an 8-digit OTP to the given email for password reset.
    func sendPasswordResetOTP(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email,
            shouldCreateUser: false
        )
    }
    
    /// Verifies the OTP code sent to the email address.
    func verifyPasswordResetOTP(email: String, otp: String) async throws {
        try await client.auth.verifyOTP(email: email, token: otp, type: .email)
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
            .eq("id", value: id.uuidString)
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
        let gender: String?
        let dateOfBirth: String?     // Supabase returns "yyyy-MM-dd" — keep as String
        let height: Double?
        let weight: Double?
        let bloodGroup: String?
        let createdAt: String?       // Extra column returned by Supabase — absorb so decode never fails
        let avatarUrl: String?       // Supabase Storage public URL for profile photo
        
        enum CodingKeys: String, CodingKey {
            case id
            case fullName       = "full_name"
            case email
            case contactNumber  = "contact_number"
            case gender
            case dateOfBirth    = "date_of_birth"
            case height
            case weight
            case bloodGroup     = "blood_group"
            case createdAt      = "created_at"
            case avatarUrl      = "avatar_url"
        }
        
        // Convert domain model → DTO (for INSERT / UPDATE — always has full data)
        init(from user: User) {
            self.id            = user.id
            self.fullName      = user.fullName
            self.email         = user.email
            self.contactNumber = user.contactNumber
            self.gender        = user.gender.rawValue
            self.dateOfBirth   = UserDTO.dateFormatter.string(from: user.dateOfBirth)
            self.height        = user.height
            self.weight        = user.weight
            self.bloodGroup    = user.bloodGroup
            self.createdAt     = nil
            self.avatarUrl     = user.avatarUrl
        }
        
        // Convert DTO → domain model — parse the "yyyy-MM-dd" date string manually
        func toDomain() -> User {
            let dob: Date = dateOfBirth.flatMap { UserDTO.dateFormatter.date(from: $0) } ?? Date()
            return User(
                id:            id,
                fullName:      fullName      ?? "",
                email:         email         ?? "",
                contactNumber: contactNumber ?? "",
                gender:        Gender(rawValue: gender ?? "") ?? .unspecified,
                dateOfBirth:   dob,
                password:      "",
                height:        height,
                weight:        weight,
                bloodGroup:    bloodGroup,
                avatarUrl:     avatarUrl
            )
        }
        
        // Shared formatter for "yyyy-MM-dd"
        private static let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            return df
        }()
    }

