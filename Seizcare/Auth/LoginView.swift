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
    @State private var isPasswordRevealed = false

    var body: some View {
        ZStack {
            Color(red: 0.961, green: 0.969, blue: 0.984).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Header
                Text("Welcome Back")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.18))

                Text("Login to continue")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
                    .padding(.top, 8)

                Spacer().frame(height: 24)

                // Form Card
                VStack(spacing: 16) {

                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

                        TextField("you@example.com", text: $vm.loginEmail)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.loginEmailError != nil ? Color.errorRed : Color(red: 0.90, green: 0.92, blue: 0.94),
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
                        Text("Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

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
                                    .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    vm.loginPasswordError != nil ? Color.errorRed : Color(red: 0.90, green: 0.92, blue: 0.94),
                                    lineWidth: vm.loginPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.loginPasswordError)
                    }

                    // Forgot password?
                    HStack {
                        Spacer()
                        Button(action: { vm.switchToForgotPassword() }) {
                            Text("Forgot password?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.27, green: 0.51, blue: 0.96))
                        }
                    }

                    Spacer().frame(height: 4)

                    // Login Button
                    Button(action: { vm.login() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.isLoginEnabled ? Color(red: 0.27, green: 0.51, blue: 0.96) : Color(red: 0.69, green: 0.82, blue: 1.0))

                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Login")
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
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)

                Spacer().frame(height: 24)

                // Switch to Sign Up
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

                    Button(action: { vm.switchToSignup() }) {
                        Text("Sign Up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.27, green: 0.51, blue: 0.96))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Login Failed", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView(vm: AuthViewModel())
}
