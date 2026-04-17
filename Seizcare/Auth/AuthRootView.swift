
//
//  AuthRootView.swift
//  Seizcare
//
//  Root authentication coordinator.
//  • Checks for an existing session on launch (auto-login).
//  • Slides between LoginView ↔ SignupView.
//  • Shows a centered success toast.
//  • Hands off to ContentView once authenticated.
//

import SwiftUI

// MARK: - AuthRootView

struct AuthRootView: View {

    @ObservedObject var vm: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if vm.isAuthenticated {
                // ── Authenticated ─────────────────────────────────────────
                // Replace this placeholder with your app's main root view
                MainAppPlaceholderView(vm: vm)
                    .transition(.opacity)
            } else {
                authFlow
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isAuthenticated)
    }

    private var authFlow: some View {
        ZStack {
            // ── Unified Minimalist Background ──────────────────────────
            Color.authBackground
                .ignoresSafeArea()

            // ── Screen switcher ────────────────────────────────────────
            Group {
                switch vm.activeScreen {
                case .onboarding:
                    OnboardingView(vm: vm)
                        .transition(.opacity)
                case .login:
                    LoginView(vm: vm)
                        .transition(
                            .asymmetric(
                                insertion:  .move(edge: .leading).combined(with: .opacity),
                                removal:    .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                case .signup:
                    SignupView(vm: vm)
                        .transition(
                            .asymmetric(
                                insertion:  .move(edge: .trailing).combined(with: .opacity),
                                removal:    .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                case .signupVerification:
                    SignupOTPView(vm: vm)
                        .transition(.opacity)
                case .setupProfile:
                    ProfileSetupView(vm: vm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .setupPhone:
                    PhoneSetupView(vm: vm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .addEmergencyContacts:
                    AddEmergencyContactsView(vm: vm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .sensitivitySetup:
                    SensitivitySetupView(vm: vm)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .forgotPasswordEmail:
                    ForgotPasswordEmailView(vm: vm)
                        .transition(
                            .asymmetric(
                                insertion:  .move(edge: .trailing).combined(with: .opacity),
                                removal:    .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                case .forgotPasswordOTP:
                    ForgotPasswordOTPView(vm: vm)
                        .transition(
                            .asymmetric(
                                insertion:  .move(edge: .trailing).combined(with: .opacity),
                                removal:    .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                case .forgotPasswordReset:
                    ForgotPasswordResetView(vm: vm)
                        .transition(
                            .asymmetric(
                                insertion:  .move(edge: .trailing).combined(with: .opacity),
                                removal:    .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.activeScreen)

            // ── Success Toast ──────────────────────────────────────────
            if vm.showSuccessToast {
                SuccessToast(message: vm.successMessage) {
                    vm.showSuccessToast = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 56)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: vm.showSuccessToast)
            }
        }
    }
}

// MARK: - Success Toast

private struct SuccessToast: View {

    let message:   String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.successGreen, Color(red: 0.1, green: 0.85, blue: 0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.authPrimaryText)
                .multilineTextAlignment(.leading)

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.authSecondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.successGreen.opacity(0.18), radius: 16, x: 0, y: 6)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Main App Placeholder
// ⚠️  Replace this with your real post-login root view (e.g. TabsView / HomeView).

private struct MainAppPlaceholderView: View {
    @ObservedObject var vm: AuthViewModel

    var body: some View {
        // Show the new SettingsView so the user can preview the changes directly
        SettingsView(vm: vm)
            .transition(.opacity)
    }
}


// MARK: - Preview

#Preview {
    AuthRootView(vm: AuthViewModel())
}
