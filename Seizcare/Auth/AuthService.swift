
//
//  AuthService.swift
//  Seizcare
//
//  Thin façade over UserDataModel / SupabaseService for the Auth flow.
//  Keeps ViewModels clean and testable.
//

import Foundation
import Supabase
import Auth

// MARK: - AuthServiceError

enum AuthServiceError: Error, LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case networkError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .emailAlreadyInUse:
            return "This email is already registered. Please log in."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .unknown(let msg):
            return msg.isEmpty ? "An unexpected error occurred." : msg
        }
    }
}

// MARK: - AuthService

final class AuthService {

    static let shared = AuthService()
    private init() {}

    // ─── Login ────────────────────────────────────────────────────────────────

    /// Authenticate with email + password.
    /// Throws a typed `AuthServiceError` on failure.
    func login(email: String, password: String) async throws {
        do {
            try await UserDataModel.shared.loginUserAsync(email: email, password: password)
        } catch {
            throw map(error)
        }
    }

    // ─── Sign-up ──────────────────────────────────────────────────────────────

    /// Register a new account.
    /// Returns `true` when a pre-existing unverified account was found and an OTP was resent.
    func signUp(email: String, password: String) async throws -> Bool {
        let tempUser = User(
            fullName:      "",
            email:         email,
            contactNumber: "",
            gender:        .unspecified,
            dateOfBirth:   Date(),
            password:      password
        )
        do {
            return try await UserDataModel.shared.initiateSignUpAsync(user: tempUser)
        } catch {
            throw map(error)
        }
    }

    /// Register a new account and immediately bypass OTP verification (Temporary).
    func signUpAndBypass(email: String, password: String) async throws -> Auth.User {
        do {
            let authUser = try await SupabaseService.shared.signUp(email: email, password: password)
            try await UserDataModel.shared.bypassVerificationAndSetupProfile(authUser: authUser, fullName: "")
            return authUser
        } catch {
            throw map(error)
        }
    }

    /// Completes registration by verifying OTP and creating the user profile row.
    func finalizeSignUp(email: String, otp: String, isResend: Bool) async throws {
        // Build a skeletal user for profile creation
        let tempUser = User(
            fullName:      "",
            email:         email,
            contactNumber: "",
            gender:        .unspecified,
            dateOfBirth:   Date(),
            password:      ""
        )
        do {
            try await UserDataModel.shared.finalizeSignUpAsync(user: tempUser, otp: otp, isResend: isResend)
        } catch {
            throw map(error)
        }
    }

    /// Establishes profile without OTP when verification is bypassed.
    func bypassVerification(authUser: Auth.User, fullName: String) async throws {
        do {
            try await UserDataModel.shared.bypassVerificationAndSetupProfile(authUser: authUser, fullName: fullName)
        } catch {
            throw map(error)
        }
    }

    // ─── Sign out ─────────────────────────────────────────────────────────────

    func signOut() async throws {
        do {
            try await SupabaseService.shared.signOut()
        } catch {
            throw map(error)
        }
    }

    // ─── Session restore ──────────────────────────────────────────────────────

    /// Re-hydrates the previous Supabase session.
    /// Returns `true` when a valid session was found.
    func restoreSession() async -> Bool {
        await UserDataModel.shared.restoreSession()
        return UserDataModel.shared.currentUser != nil
    }

    // ─── Forgot Password ──────────────────────────────────────────────────────

    /// Sends an OTP code to the given email for password reset.
    func sendPasswordResetOTP(email: String) async throws {
        do {
            try await SupabaseService.shared.sendPasswordResetOTP(email: email)
        } catch {
            throw map(error)
        }
    }

    /// Verifies the OTP code sent to the email address.
    func verifyPasswordResetOTP(email: String, otp: String) async throws {
        do {
            try await SupabaseService.shared.verifyPasswordResetOTP(email: email, otp: otp)
        } catch {
            throw map(error)
        }
    }

    /// Updates the current user's password after OTP verification.
    func updateUserPassword(newPassword: String) async throws {
        do {
            try await SupabaseService.shared.updateUserPassword(newPassword: newPassword)
        } catch {
            throw map(error)
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private func map(_ error: Error) -> AuthServiceError {
        let msg = error.localizedDescription.lowercased()

        if msg.contains("invalid login credentials") ||
           msg.contains("invalid email or password") ||
           msg.contains("email not confirmed") {
            return .invalidCredentials
        }
        if msg.contains("already registered") ||
           msg.contains("already in use") ||
           msg.contains("already exists") {
            return .emailAlreadyInUse
        }
        if msg.contains("network") ||
           msg.contains("internet") ||
           msg.contains("offline") {
            return .networkError(error.localizedDescription)
        }
        return .unknown(error.localizedDescription)
    }
}
