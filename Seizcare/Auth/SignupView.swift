//
//  SignupView.swift
//  Seizcare
//
//  Minimalist Sign Up Screen
//

import SwiftUI

// MARK: - SignupView

struct SignupView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @State private var isPasswordRevealed = false
    @State private var isConfirmPasswordRevealed = false

    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Header
                Text("create_account".localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)

                Text("join_seizcare".localized)
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

                        TextField("you@example.com", text: $vm.signupEmail)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.authFieldBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.signupEmailError != nil ? Color.errorRed : Color.authInputBorder,
                                        lineWidth: vm.signupEmailError != nil ? 1.5 : 1
                                    )
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .animation(.easeInOut(duration: 0.2), value: vm.signupEmailError)
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("password".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isPasswordRevealed {
                                    TextField("........", text: $vm.signupPassword)
                                } else {
                                    SecureField("........", text: $vm.signupPassword)
                                }
                            }
                            .font(.system(size: 15))
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

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
                                    vm.signupPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.signupPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.signupPasswordError)
                    }

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("confirm_password".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        SecureField("........", text: $vm.signupConfirmPassword)
                            .font(.system(size: 15))
                            .textContentType(.newPassword)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.authFieldBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.signupConfirmPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                        lineWidth: vm.signupConfirmPasswordError != nil ? 1.5 : 1
                                    )
                            )
                            .animation(.easeInOut(duration: 0.2), value: vm.signupConfirmPasswordError)
                    }

                    Spacer().frame(height: 8)

                    // Signup Button
                    Button(action: { vm.signUp() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.isSignupEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)

                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("sign_up".localized)
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

                // Switch to Login
                HStack(spacing: 4) {
                    Text("already_have_account".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.authSecondaryText)

                    Button(action: { vm.switchToLogin() }) {
                        Text("login".localized)
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
        .alert("error".localized, isPresented: $vm.showAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    SignupView(vm: AuthViewModel())
}
