
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

    @StateObject private var vm = AuthViewModel()
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
        .task {
            // Auto-login: try restoring a prior Supabase session
            await vm.tryRestoreSession()
        }
    }

    private var authFlow: some View {
        ZStack {
            // ── Unified Minimalist Background ──────────────────────────
            Color(red: 0.961, green: 0.969, blue: 0.984)
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
        ZStack {
            Color(red: 0.961, green: 0.969, blue: 0.984).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.27, green: 0.51, blue: 0.96), Color(red: 0.40, green: 0.36, blue: 0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                Text("You're logged in!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)

                Text("Replace this view with your real app.")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)

                Spacer().frame(height: 16)

                Button(action: { vm.logout() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.95, green: 0.28, blue: 0.33))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.95, green: 0.28, blue: 0.33).opacity(0.08))
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthRootView()
}
