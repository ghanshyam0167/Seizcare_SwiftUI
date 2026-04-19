//
//  LoginView.swift
//  Seizcare
//
//  Minimalist Login Screen
//

import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @State private var isPasswordRevealed = false

    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Header
                Text("welcome_back".localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)

                Text("login_to_continue".localized)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.authSecondaryText)
                    .padding(.top, 8)

                Spacer().frame(height: 24)

                // Form Card
                VStack(spacing: 16) {

                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("email".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        TextField("you@example.com", text: $vm.loginEmail)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.authFieldBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.loginEmailError != nil ? Color.errorRed : Color.authInputBorder,
                                        lineWidth: vm.loginEmailError != nil ? 1.5 : 1
                                    )
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .animation(.easeInOut(duration: 0.2), value: vm.loginEmailError)
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("password".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isPasswordRevealed {
                                    TextField("........", text: $vm.loginPassword)
                                } else {
                                    SecureField("........", text: $vm.loginPassword)
                                }
                            }
                            .font(.system(size: 15))

                            Button(action: { isPasswordRevealed.toggle() }) {
                                Image(systemName: isPasswordRevealed ? "eye.slash" : "eye")
                                    .foregroundColor(.authSecondaryText)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.authFieldBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    vm.loginPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.loginPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.loginPasswordError)
                    }

                    // Forgot password?
                    HStack {
                        Spacer()
                        Button(action: { vm.switchToForgotPassword() }) {
                            Text("forgot_password_question".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.authPrimaryButton)
                        }
                    }

                    Spacer().frame(height: 4)

                    // Login Button
                    Button(action: { vm.login() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.isLoginEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)

                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("login".localized)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 52)
                    }
                    .disabled(vm.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.authCardBackground)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)

                Spacer().frame(height: 24)

                // Switch to Sign Up
                HStack(spacing: 4) {
                    Text("dont_have_account".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.authSecondaryText)

                    Button(action: { vm.switchToSignup() }) {
                        Text("sign_up".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.authPrimaryButton)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("login_failed".localized, isPresented: $vm.showAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView(vm: AuthViewModel())
}
