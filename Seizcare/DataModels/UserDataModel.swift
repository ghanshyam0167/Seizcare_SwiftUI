//
//  UserDataModel.swift
//  Seizcare

import Foundation
import Auth
import Supabase
import UIKit


//  User Model
struct User: Identifiable, Codable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var contactNumber: String
    var password: String       // Kept for model compatibility; auth is handled by Supabase Auth

    // Profile photo (Supabase Storage public URL)
    var avatarUrl: String?

    init(
        id: UUID = UUID(),
        fullName: String,
        email: String,
        contactNumber: String = "",
        password: String,
        avatarUrl: String? = nil
    ) {
        self.id            = id
        self.fullName      = fullName
        self.email         = email
        self.contactNumber = contactNumber
        self.password      = password
        self.avatarUrl     = avatarUrl
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

//  User Data Model
class UserDataModel {

    static let shared = UserDataModel()

    // In-memory session — Supabase is the only source of truth.
    // This is populated by signUpUserAsync / loginUserAsync / restoreSession.
    private(set) var currentUser: User?

    private let currentUserKey = "currentUserId"

    private init() {}

    // MARK: - Session Restore
    // Call this once from SceneDelegate/AppDelegate after the app launches.
    // Restores the authenticated session entirely from Supabase (not from a local cache).

    /// Re-authenticates the Supabase session and fetches the user profile.
    /// Call from SceneDelegate.sceneWillEnterForeground or AppDelegate.didFinishLaunching.
    func restoreSession() async {
        do {
            // Ask Supabase Auth for the current session user id
            guard let uid = await SupabaseService.shared.currentUserId() else {
                currentUser = nil
                return
            }
            let dto = try await SupabaseService.shared.fetchUser(id: uid)
            currentUser = dto?.toDomain()
            if let id = currentUser?.id {
                UserDefaults.standard.set(id.uuidString, forKey: currentUserKey)
            }
            // Ensure avatar refresh on a new device/session where no local image exists yet.
            NotificationCenter.default.post(name: UserDataModel.avatarDidChangeNotification, object: nil)
        } catch {
            print("⚠️ [UserDataModel] restoreSession failed:", error.localizedDescription)
            currentUser = nil
        }
    }

    // MARK: - Current User

    func getCurrentUser() -> User? {
        return currentUser
    }

    /// Updates the current user's profile in Supabase and refreshes the local session.
    func updateCurrentUser(_ updatedUser: User) {
        currentUser = updatedUser
        UserDefaults.standard.set(updatedUser.id.uuidString, forKey: currentUserKey)
        Task {
            do {
                try await SupabaseService.shared.updateUser(UserDTO(from: updatedUser))
            } catch {
                print("⚠️ [UserDataModel] updateCurrentUser failed:", error.localizedDescription)
            }
        }
    }

    // MARK: - Backward Compat (used by some VCs)

    /// Returns the current user in an array if set, otherwise empty — replaces the old getAllUsers().
    func getAllUsers() -> [User] {
        return currentUser.map { [$0] } ?? []
    }

    // MARK: - Avatar

    /// Notification broadcast after the avatar URL is updated.
    /// All screens observing this will reload the avatar image automatically.
    static let avatarDidChangeNotification = Notification.Name("UserAvatarDidChange")

    /// Updates the in-memory avatar URL, persists to Supabase, then broadcasts a notification.
    func updateAvatarURL(_ url: String) {
        currentUser?.avatarUrl = url.isEmpty ? nil : url
        // Broadcast immediately so UI updates without waiting for the network call
        NotificationCenter.default.post(name: UserDataModel.avatarDidChangeNotification, object: nil)
        guard let userId = currentUser?.id else { return }
        Task {
            do {
                if url.isEmpty {
                    try await SupabaseService.shared.updateUserAvatar(userId: userId, url: "")
                } else {
                    try await SupabaseService.shared.updateUserAvatar(userId: userId, url: url)
                }
                print("✅ [UserDataModel] avatar_url saved for user \(userId)")
            } catch {
                print("⚠️ [UserDataModel] updateAvatarURL failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Local Image Storage
    
    func saveLocalAvatarImage(_ image: UIImage) {
        guard let userId = currentUser?.id else { return }
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = getLocalAvatarURL(for: userId)
            try? data.write(to: url)
            NotificationCenter.default.post(name: UserDataModel.avatarDidChangeNotification, object: nil)
        }
    }
    
    func getLocalAvatarImage() -> UIImage? {
        guard let userId = currentUser?.id else { return nil }
        let url = getLocalAvatarURL(for: userId)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
    
    func clearLocalAvatarImage() {
        guard let userId = currentUser?.id else { return }
        let url = getLocalAvatarURL(for: userId)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getLocalAvatarURL(for userId: UUID? = nil) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let uid = userId ?? currentUser?.id
        let filename = uid.map { "avatar_\($0.uuidString.lowercased()).jpg" } ?? "local_avatar.jpg"
        return paths[0].appendingPathComponent(filename)
    }

}

//  - Authentication Extension
extension UserDataModel {

    // MARK: - Data Sync



    /// Async sign-in. Fetches user profile from Supabase after auth succeeds.
    /// Await this before navigating to protected screens.
    func loginUserAsync(email: String, password: String) async throws {
        print("[Auth] Attempting sign-in for: \(email)")

        // Step 1 — Supabase Auth. This throws if credentials are wrong OR
        // if the account email has not been confirmed yet.
        let uid: UUID
        do {
            uid = try await SupabaseService.shared.signIn(email: email, password: password)
            print("[Auth] Supabase Auth OK — uid: \(uid)")
        } catch {
            print("[Auth] Supabase signIn FAILED:", error.localizedDescription)
            // Re-throw so the VC can surface the real reason
            throw error
        }

        // Step 2 — Fetch profile row from the users table.
        let dto: UserDTO?
        do {
            dto = try await SupabaseService.shared.fetchUser(id: uid)
        } catch {
            print("[Auth] fetchUser FAILED:", error.localizedDescription)
            dto = nil   // treat as missing profile; fall through to graceful path
        }

        if let user = dto?.toDomain() {
            print("[Auth] Profile found: \(user.fullName)")
            currentUser = user
        } else {
            // Auth succeeded but no profile row exists yet (e.g. row was never
            // inserted, or the users table is empty). Build a minimal session
            // from what we know so the app still navigates correctly.
            print("[Auth] No profile row found — creating minimal session for uid \(uid)")
            let minimal = User(
                id:            uid,
                fullName:      "",
                email:         email,
                password:      ""
            )
            currentUser = minimal
        }
        UserDefaults.standard.set(uid.uuidString, forKey: currentUserKey)
        // Triggers AvatarViewModel to fetch remote avatarUrl on new devices.
        NotificationCenter.default.post(name: UserDataModel.avatarDidChangeNotification, object: nil)
    }

    /// Legacy synchronous wrapper — kept for backward compatibility.
    /// Prefer loginUserAsync for new or refactored call sites.
    @discardableResult
    func loginUser(emailOrPhone: String, password: String) -> Bool {
        Task {
            do {
                try await loginUserAsync(email: emailOrPhone, password: password)
            } catch {
                print("⚠️ [UserDataModel] loginUser failed:", error.localizedDescription)
            }
        }
        return true   // optimistic; real result comes via currentUser being set
    }

    /// Register via Supabase Auth without establishing a profile yet.
    /// This triggers the OTP email from Supabase natively.
    /// Returns true if the user was already registered but unverified (OTP resent), false otherwise.
    func initiateSignUpAsync(user: User) async throws -> Bool {
        do {
            let authUser: Auth.User = try await SupabaseService.shared.signUp(email: user.email, password: user.password)
            
            // Check if the user is already confirmed/verified
            if authUser.confirmedAt != nil {
                throw SupabaseServiceError.authFailed("This email is already registered and verified. Please log in.")
            }
            
            // If the user already existed but was NOT confirmed, Supabase might not send an email
            // (especially in the 'user_repeated_signup' scenario seen in logs).
            // If identities is empty or count is same but unconfirmed, we force a resend.
            if authUser.identities?.isEmpty ?? true {
                try await SupabaseService.shared.resendSignUpOTP(email: user.email)
                return true
            }
            
            return false
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("user already registered") {
                // If the error explicitly says registered, force resend
                try await SupabaseService.shared.resendSignUpOTP(email: user.email)
                return true
            }
            throw error
        }
    }
    
    /// Called when the user submits a valid 8-digit OTP from their email.
    /// Verifies the code, and if successful, establishes the user profile and local session.
    /// - Parameter isResend: When true, the OTP was sent via signInWithOTP (type: .email).
    ///                       When false, it was sent via signUp (type: .signup).
    func finalizeSignUpAsync(user: User, otp: String, isResend: Bool = false) async throws {
        print("[finalizeSignUp] Starting. isResend=\(isResend) email=\(user.email)")
        
        // 1. Verify OTP with Supabase Auth – pick the right type based on how OTP was sent
        let uid: UUID
        if isResend {
            print("[finalizeSignUp] Verifying with type .email")
            uid = try await SupabaseService.shared.verifyEmailOTP(email: user.email, otp: otp)
        } else {
            print("[finalizeSignUp] Verifying with type .signup")
            uid = try await SupabaseService.shared.verifySignUpOTP(email: user.email, otp: otp)
        }
        print("[finalizeSignUp] OTP verified. uid=\(uid)")
        
        // 2. Establish Profile (upsert so we don't conflict if a partial row exists)
        let profileUser = User(
            id:            uid,
            fullName:      user.fullName,
            email:         user.email,
            contactNumber: user.contactNumber,
            password:      ""
        )
        print("[finalizeSignUp] Inserting/upserting profile row...")
        do {
            try await SupabaseService.shared.insertUser(UserDTO(from: profileUser))
            print("[finalizeSignUp] Profile inserted.")
        } catch {
            // If a row already exists (e.g., from a previous partial signup), that's okay
            let msg = error.localizedDescription.lowercased()
            if msg.contains("duplicate") || msg.contains("already exists") || msg.contains("unique") {
                print("[finalizeSignUp] Profile row already exists – skipping insert.")
            } else {
                print("[finalizeSignUp] Insert error: \(error)")
                throw error
            }
        }
        
        // 3. Establish Local Session
        print("[finalizeSignUp] Setting currentUser and UserDefaults")
        currentUser = profileUser
        UserDefaults.standard.set(profileUser.id.uuidString, forKey: currentUserKey)
        
        print("[finalizeSignUp] Done.")
    }

    /// Establishes a profile and local session immediately without OTP verification.
    /// Used when the verification flow is temporarily detached.
    func bypassVerificationAndSetupProfile(authUser: Auth.User, fullName: String) async throws {
        print("[bypassVerification] Starting for ID: \(authUser.id)")
        
        // 1. Establish Profile
        let profileUser = User(
            id:            authUser.id,
            fullName:      fullName,
            email:         authUser.email ?? "",
            password:      ""
        )
        
        do {
            try await SupabaseService.shared.insertUser(UserDTO(from: profileUser))
            print("[bypassVerification] Profile inserted.")
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("duplicate") || msg.contains("already exists") {
                print("[bypassVerification] Profile row already exists.")
            } else {
                throw error
            }
        }
        
        // 2. Establish Local Session
        currentUser = profileUser
        UserDefaults.standard.set(profileUser.id.uuidString, forKey: currentUserKey)
        print("[bypassVerification] Session established.")
    }

    func logoutUser(completion: @escaping (Bool) -> Void) {
        // Clear user-scoped local avatar before wiping the session
        clearLocalAvatarImage()
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        Task { try? await SupabaseService.shared.signOut() }
        completion(true)
    }
    
    // MARK: - Account Deletion
    
    /// Completely deletes the user's account backend data, wipes the local active session, and signs out.
    func deleteAccountAsync() async throws {
        // 1. Invoke Edge Function to physically delete all data
        try await SupabaseService.shared.deleteAccount()
        
        // 2. Wipe Local State
        clearLocalAvatarImage()
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        
        // 3. Clear Supabase Auth local session
        try? await SupabaseService.shared.signOut()
    }
    
    // MARK: - Password Reset (OTP)
    
    /// Requests an OTP code to be sent to the user's email.
    func sendPasswordResetOTPAsync(email: String) async throws {
        try await SupabaseService.shared.sendPasswordResetOTP(email: email)
    }
    
    /// Verifies the provided OTP code against the user's email.
    func verifyPasswordResetOTPAsync(email: String, otp: String) async throws {
        try await SupabaseService.shared.verifyPasswordResetOTP(email: email, otp: otp)
    }
    
    /// Updates the password using the authenticated active session from the prior verified OTP.
    func updateUserPasswordAsync(newPassword: String) async throws {
        try await SupabaseService.shared.updateUserPassword(newPassword: newPassword)
    }
    

}
