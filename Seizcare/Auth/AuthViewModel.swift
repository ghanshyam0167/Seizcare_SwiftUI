
//
//  AuthViewModel.swift
//  Seizcare
//
//  Single MVVM ViewModel driving both Login and Signup screens.
//  Uses async/await with @MainActor for thread-safe UI updates.
//

import SwiftUI
import Combine

// MARK: - AuthScreen

enum AuthScreen {
    case onboarding
    case login
    case signup
    case signupVerification
    case setupProfile
    case setupPhone
    case addEmergencyContacts
    case sensitivitySetup
    case forgotPasswordEmail
    case forgotPasswordOTP
    case forgotPasswordReset
}

// MARK: - AuthViewModel

@MainActor
final class AuthViewModel: ObservableObject {

    // ─── Shared state ────────────────────────────────────────────────────────
    @Published var activeScreen: AuthScreen = .onboarding

    // ─── Login fields ────────────────────────────────────────────────────────
    @Published var loginEmail:    String = ""
    @Published var loginPassword: String = ""

    // ─── Signup fields ───────────────────────────────────────────────────────
    @Published var signupEmail:           String = ""
    @Published var signupPassword:        String = ""
    @Published var signupConfirmPassword: String = ""
    @Published var signupOTP:             String = ""
    @Published var isResendSignupOTP:     Bool   = false

    // ─── Onboarding fields ───────────────────────────────────────────────────
    @Published var onboardingFullName:    String = ""
    @Published var onboardingPhoneNumber: String = ""
    @Published var onboardingProfileImage: UIImage? = nil

    // ─── Forgot Password fields ──────────────────────────────────────────────
    @Published var forgotPasswordEmail:   String = ""
    @Published var forgotPasswordOTP:     String = ""
    @Published var resetPassword:         String = ""
    @Published var resetConfirmPassword:  String = ""

    // ─── Change Password fields ──────────────────────────────────────────────
    @Published var changeCurrentPassword:  String = ""
    @Published var changeNewPassword:      String = ""
    @Published var changeConfirmPassword:  String = ""
    @Published var isChangePasswordPresented: Bool = false

    // ─── Validation errors ───────────────────────────────────────────────────
    @Published var loginEmailError:           String? = nil
    @Published var loginPasswordError:        String? = nil

    @Published var signupEmailError:          String? = nil
    @Published var signupPasswordError:       String? = nil
    @Published var signupConfirmPasswordError:String? = nil

    @Published var forgotPasswordEmailError:  String? = nil
    @Published var resetPasswordError:        String? = nil
    @Published var resetConfirmPasswordError: String? = nil

    @Published var changeCurrentPasswordError: String? = nil
    @Published var changeNewPasswordError:     String? = nil
    @Published var changeConfirmPasswordError: String? = nil

    // ─── Async state ─────────────────────────────────────────────────────────
    @Published var isLoading:        Bool   = false
    @Published var alertMessage:     String = ""
    @Published var showAlert:        Bool   = false
    @Published var showSuccessToast: Bool   = false
    @Published var successMessage:   String = ""

    // ─── Navigation ─────────────────────────────────────────────────────────
    @Published var isAuthenticated:  Bool   = false

    // ─── Shake triggers ─────────────────────────────────────────────────────
    @Published var loginShakeTrigger:  CGFloat = 0
    @Published var signupShakeTrigger: CGFloat = 0

    private let service = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        bindRealtimeValidation()
    }

    // MARK: - Realtime Validation Bindings

    private func bindRealtimeValidation() {
        // Login
        $loginEmail
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.loginEmailError = self?.emailError(for: val)
            }
            .store(in: &cancellables)

        $loginPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                // Show red border for 1–5 chars; clear when empty or 6+
                self?.loginPasswordError = (!val.isEmpty && val.count < 6) ? "too short" : nil
            }
            .store(in: &cancellables)

        // Signup
        $signupEmail
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.signupEmailError = self?.emailError(for: val)
            }
            .store(in: &cancellables)

        $signupPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.signupPasswordError = self?.passwordStrengthError(for: val)
                // also re-validate confirm
                if let confirm = self?.signupConfirmPassword, !confirm.isEmpty {
                    self?.signupConfirmPasswordError = confirm == val ? nil : "Passwords don't match"
                }
            }
            .store(in: &cancellables)

        $signupConfirmPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                guard let self else { return }
                self.signupConfirmPasswordError = val.isEmpty ? nil
                    : (val == self.signupPassword ? nil : "Passwords don't match")
            }
            .store(in: &cancellables)

        // Forgot Password
        $forgotPasswordEmail
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.forgotPasswordEmailError = self?.emailError(for: val)
            }
            .store(in: &cancellables)
            
        $resetPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.resetPasswordError = self?.passwordStrengthError(for: val)
                if let confirm = self?.resetConfirmPassword, !confirm.isEmpty {
                    self?.resetConfirmPasswordError = confirm == val ? nil : "Passwords don't match"
                }
            }
            .store(in: &cancellables)
            
        $resetConfirmPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                guard let self else { return }
                self.resetConfirmPasswordError = val.isEmpty ? nil
                    : (val == self.resetPassword ? nil : "Passwords don't match")
            }
            .store(in: &cancellables)

        // Change Password
        $changeCurrentPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.changeCurrentPasswordError = val.isEmpty ? "Current password required" : nil
            }
            .store(in: &cancellables)

        $changeNewPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                self?.changeNewPasswordError = self?.passwordStrengthError(for: val)
                if let confirm = self?.changeConfirmPassword, !confirm.isEmpty {
                    self?.changeConfirmPasswordError = confirm == val ? nil : "Passwords don't match"
                }
            }
            .store(in: &cancellables)

        $changeConfirmPassword
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] val in
                guard let self else { return }
                self.changeConfirmPasswordError = val.isEmpty ? nil
                    : (val == self.changeNewPassword ? nil : "Passwords don't match")
            }
            .store(in: &cancellables)
    }

    // MARK: - Validation Helpers

    private func emailError(for value: String) -> String? {
        guard !value.isEmpty else { return nil }
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return value.range(of: regex, options: .regularExpression) == nil
            ? "Enter a valid email address" : nil
    }

    private func passwordStrengthError(for value: String) -> String? {
        if value.isEmpty { return nil }
        if value.count < 6 { return "At least 6 characters required" }
        return nil
    }

    // MARK: - Login Validation

    @discardableResult
    private func validateLogin() -> Bool {
        loginEmailError    = emailError(for: loginEmail) ?? (loginEmail.isEmpty ? "Email is required" : nil)
        loginPasswordError = loginPassword.isEmpty ? "Password is required" : nil
        return loginEmailError == nil && loginPasswordError == nil
    }

    var isLoginEnabled: Bool {
        !loginEmail.isEmpty && loginPassword.count >= 6
            && emailError(for: loginEmail) == nil
    }

    // MARK: - Signup Validation

    @discardableResult
    private func validateSignup() -> Bool {
        signupEmailError           = emailError(for: signupEmail) ?? (signupEmail.isEmpty ? "Email is required" : nil)
        signupPasswordError        = passwordStrengthError(for: signupPassword) ?? (signupPassword.isEmpty ? "Password is required" : nil)
        signupConfirmPasswordError = signupConfirmPassword.isEmpty ? "Please confirm your password"
            : (signupConfirmPassword == signupPassword ? nil : "Passwords don't match")
        return signupEmailError == nil
            && signupPasswordError == nil
            && signupConfirmPasswordError == nil
    }

    var isSignupEnabled: Bool {
        !signupEmail.isEmpty
            && !signupPassword.isEmpty
            && !signupConfirmPassword.isEmpty
            && emailError(for: signupEmail) == nil
            && passwordStrengthError(for: signupPassword) == nil
            && signupConfirmPassword == signupPassword
    }

    var isSignupOTPEnabled: Bool {
        signupOTP.count == 8
    }

    // MARK: - Forgot Password Validation

    var isForgotPasswordEmailEnabled: Bool {
        !forgotPasswordEmail.isEmpty && emailError(for: forgotPasswordEmail) == nil
    }
    
    var isForgotPasswordOTPEnabled: Bool {
        forgotPasswordOTP.count == 8
    }
    
    var isForgotPasswordResetEnabled: Bool {
        !resetPassword.isEmpty && !resetConfirmPassword.isEmpty
            && passwordStrengthError(for: resetPassword) == nil
            && resetConfirmPassword == resetPassword
    }

    // MARK: - Change Password Validation
    
    var isChangePasswordEnabled: Bool {
        !changeCurrentPassword.isEmpty && !changeNewPassword.isEmpty && !changeConfirmPassword.isEmpty
            && passwordStrengthError(for: changeNewPassword) == nil
            && changeConfirmPassword == changeNewPassword
    }

    // MARK: - Password Strength Indicator

    enum PasswordStrength { case empty, weak_, fair, strong }

    var signupPasswordStrength: PasswordStrength {
        let val = signupPassword
        if val.isEmpty { return .empty }
        var score = 0
        if val.count >= 8  { score += 1 }
        if val.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if val.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if val.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        switch score {
        case 1:  return .weak_
        case 2:  return .fair
        default: return .strong
        }
    }

    // MARK: - Actions

    func login() {
        guard validateLogin() else {
            withAnimation(.default) { loginShakeTrigger += 1 }
            return
        }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await service.login(email: loginEmail.trimmingCharacters(in: .whitespaces),
                                        password: loginPassword)
                
                // Sync user data
                await EmergencyContactDataModel.shared.refreshContacts()
                await SensitivityDataModel.shared.refreshSensitivity()
                
                isAuthenticated = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert    = true
                withAnimation(.default) { loginShakeTrigger += 1 }
            }
        }
    }

    func signUp() {
        guard validateSignup() else {
            withAnimation(.default) { signupShakeTrigger += 1 }
            return
        }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                _ = try await service.signUpAndBypass(
                    email:    signupEmail.trimmingCharacters(in: .whitespaces),
                    password: signupPassword
                )
                
                triggerSuccessToast(message: "Account created! Let's setup your profile.")
                withAnimation(.spring()) { activeScreen = .setupProfile }
            } catch let e as AuthServiceError {
                if case .emailAlreadyInUse = e {
                    // Friendly nudge to log in instead
                    alertMessage = "This email is already registered. Please log in."
                } else {
                    alertMessage = e.localizedDescription
                }
                showAlert = true
                withAnimation(.default) { signupShakeTrigger += 1 }
            } catch {
                alertMessage = error.localizedDescription
                showAlert    = true
            }
        }
    }

    func verifySignupOTP() {
        guard isSignupOTPEnabled else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await service.finalizeSignUp(
                    email: signupEmail.trimmingCharacters(in: .whitespaces),
                    otp: signupOTP,
                    isResend: isResendSignupOTP
                )
                
                // Sync user data
                await EmergencyContactDataModel.shared.refreshContacts()
                await SensitivityDataModel.shared.refreshSensitivity()
                
                triggerSuccessToast(message: "Account verified successfully!")
                isAuthenticated = true
            } catch {
                alertMessage = "Invalid or expired verification code."
                showAlert = true
            }
        }
    }
    
    func finishOnboarding() {
        // Minimum 1 contact required - checked in UI, but safe to guard here
        withAnimation(.spring()) {
            activeScreen = .sensitivitySetup
        }
    }
    
    func completeSensitivitySetup() {
        isAuthenticated = true
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func switchToSignup() {
        dismissKeyboard()
        // Clear login fields
        loginEmail = ""
        loginPassword = ""
        loginEmailError = nil
        loginPasswordError = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                self.activeScreen = .signup
            }
        }
    }

    func switchToLogin() {
        dismissKeyboard()
        // Clear signup & forgot-password fields
        signupEmail = ""
        signupPassword = ""
        signupConfirmPassword = ""
        signupEmailError = nil
        signupPasswordError = nil
        signupConfirmPasswordError = nil
        signupOTP = ""
        isResendSignupOTP = false
        forgotPasswordEmail = ""
        forgotPasswordOTP = ""
        resetPassword = ""
        resetConfirmPassword = ""
        forgotPasswordEmailError = nil
        resetPasswordError = nil
        resetConfirmPasswordError = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                self.activeScreen = .login
            }
        }
    }
    
    func switchToForgotPassword() {
        // Pre-fill from login email if available
        if forgotPasswordEmail.isEmpty && !loginEmail.isEmpty {
            forgotPasswordEmail = loginEmail
        }
        // Clear OTP & reset fields
        forgotPasswordOTP = ""
        resetPassword = ""
        resetConfirmPassword = ""
        resetPasswordError = nil
        resetConfirmPasswordError = nil
        dismissKeyboard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                self.activeScreen = .forgotPasswordEmail
            }
        }
    }
    
    // MARK: - Forgot Password Flow Actions
    
    func sendPasswordReset() {
        guard isForgotPasswordEmailEnabled else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await service.sendPasswordResetOTP(email: forgotPasswordEmail.trimmingCharacters(in: .whitespaces))
                withAnimation(.spring()) {
                    activeScreen = .forgotPasswordOTP
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    func verifyResetOTP() {
        guard isForgotPasswordOTPEnabled else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await service.verifyPasswordResetOTP(
                    email: forgotPasswordEmail.trimmingCharacters(in: .whitespaces), 
                    otp: forgotPasswordOTP
                )
                withAnimation(.spring()) {
                    activeScreen = .forgotPasswordReset
                }
            } catch {
                alertMessage = "Invalid or expired OTP."
                showAlert = true
            }
        }
    }
    
    func updatePassword() {
        guard isForgotPasswordResetEnabled else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await service.updateUserPassword(newPassword: resetPassword)
                loginPassword = resetPassword
                triggerSuccessToast(message: "Password successfully reset.")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.spring()) {
                    activeScreen = .login
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    func changePassword() {
        guard let email = UserDataModel.shared.getCurrentUser()?.email else { return }
        guard isChangePasswordEnabled else { return }
        
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                // Verify current password to prevent unauthorized changes
                _ = try await SupabaseService.shared.signIn(email: email, password: changeCurrentPassword)
                
                // Update password
                try await service.updateUserPassword(newPassword: changeNewPassword)
                
                // Clear fields
                changeCurrentPassword = ""
                changeNewPassword = ""
                changeConfirmPassword = ""
                
                // Re-login isn't strictly necessary for session if we update the stored session,
                // but signing in just generated a fresh local session automatically anyway.
                triggerSuccessToast(message: "Password changed successfully!")
                
                // Allow UI to dismiss
                withAnimation(.spring()) {
                    self.isChangePasswordPresented = false
                }
            } catch {
                if error.localizedDescription.contains("Invalid login credentials") {
                    alertMessage = "Incorrect current password."
                } else {
                    alertMessage = error.localizedDescription
                }
                showAlert = true
            }
        }
    }

    private func triggerSuccessToast(message: String) {
        successMessage = message
        withAnimation(.spring()) {
            showSuccessToast = true
        }
        
        // Auto-dismiss after 3.5 seconds
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeInOut) {
                showSuccessToast = false
            }
        }
    }

    // MARK: - Session Restore

    func tryRestoreSession() async {
        let restored = await service.restoreSession()
        if restored {
            // Re-hydrate user preferences
            await EmergencyContactDataModel.shared.refreshContacts()
            await SensitivityDataModel.shared.refreshSensitivity()
        }
        isAuthenticated = restored
    }

    // MARK: - Logout

    func logout() {
        print("🔄 [AuthViewModel] Starting logout process...")
        
        // 1. Force immediate UI state change on MainActor with animation
        withAnimation(.easeInOut(duration: 0.35)) {
            self.objectWillChange.send()
            self.activeScreen = .login
            self.isAuthenticated = false
        }
        
        // 2. Perform background cleanup
        Task {
            try? await service.signOut()
            
            // Clear local caches
            EmergencyContactDataModel.shared.clearCache()
            SensitivityDataModel.shared.resetToDefault()
            
            loginEmail = ""
            loginPassword = ""
            signupEmail = ""
            signupPassword = ""
            signupConfirmPassword = ""
        }
    }

    func deleteAccount() {
        print("🗑️ [AuthViewModel] deleteAccount() called")
        isLoading = true
        Task {
            defer { 
                isLoading = false
            }
            
            do {
                print("📲 [AuthViewModel] Calling SupabaseService.deleteAccount()...")
                try await SupabaseService.shared.deleteAccount()
                print("✅ [AuthViewModel] Delete success confirmed by server.")
                // ONLY logout on success
                print("🔄 [AuthViewModel] Transitioning to login screen.")
                logout()
            } catch {
                print("⚠️ [AuthViewModel] Server deletion failed: \(error.localizedDescription)")
            }
        }
    }

    func logoutAndGoToForgotPassword() {
        print("🔄 [AuthViewModel] Logout and redirect to Forgot Password...")
        
        let currentEmail = UserDataModel.shared.getCurrentUser()?.email ?? loginEmail
        
        withAnimation(.easeInOut(duration: 0.35)) {
            self.objectWillChange.send()
            self.isAuthenticated = false
            self.activeScreen = .forgotPasswordEmail
            self.forgotPasswordEmail = currentEmail
            self.forgotPasswordOTP = ""
            self.resetPassword = ""
            self.resetConfirmPassword = ""
            self.resetPasswordError = nil
            self.resetConfirmPasswordError = nil
        }
        
        Task {
            try? await service.signOut()
            EmergencyContactDataModel.shared.clearCache()
            SensitivityDataModel.shared.resetToDefault()
            
            loginEmail = ""
            loginPassword = ""
            signupEmail = ""
            signupPassword = ""
            signupConfirmPassword = ""
        }
    }

    // MARK: - Onboarding Actions

    func saveProfileAndContinue() {
        guard !onboardingFullName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Update local session via existing updateCurrentUser method
        if var user = UserDataModel.shared.getCurrentUser() {
            user.fullName = onboardingFullName
            UserDataModel.shared.updateCurrentUser(user)
        }
        
        // If image provided, upload it
        if let image = onboardingProfileImage, let data = image.jpegData(compressionQuality: 0.7) {
            Task {
                if let userId = UserDataModel.shared.getCurrentUser()?.id {
                    do {
                        let url = try await SupabaseService.shared.uploadAvatar(userId: userId, imageData: data)
                        UserDataModel.shared.updateAvatarURL(url)
                    } catch {
                        print("Failed to upload avatar: \(error)")
                    }
                }
            }
        }
        
        withAnimation(.spring()) {
            activeScreen = .setupPhone
        }
    }
    
    func goBack() {
        withAnimation(.spring()) {
            switch activeScreen {
            case .setupPhone:
                activeScreen = .setupProfile
            case .addEmergencyContacts:
                activeScreen = .setupPhone
            case .sensitivitySetup:
                activeScreen = .addEmergencyContacts
            default:
                break
            }
        }
    }
    
    func savePhoneAndContinue() {
        if !onboardingPhoneNumber.isEmpty {
            if let user = UserDataModel.shared.getCurrentUser() {
                var updated = user
                updated.contactNumber = onboardingPhoneNumber
                UserDataModel.shared.updateCurrentUser(updated)
            }
        }
        
        withAnimation(.spring()) {
            activeScreen = .addEmergencyContacts
        }
    }
}
