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
    @State private var isPasswordRevealed = false
    @State private var isConfirmPasswordRevealed = false

    var body: some View {
        ZStack {
            Color(red: 0.961, green: 0.969, blue: 0.984).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Header
                Text("Create Account")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.18))

                Text("Join Seizcare")
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

                        TextField("you@example.com", text: $vm.signupEmail)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        vm.signupEmailError != nil ? Color.errorRed : Color(red: 0.90, green: 0.92, blue: 0.94),
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
                        Text("Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

                        HStack {
                            Group {
                                if isPasswordRevealed {
                                    TextField("Min. 6 characters", text: $vm.signupPassword)
                                } else {
                                    SecureField("Min. 6 characters", text: $vm.signupPassword)
                                }
                            }
                            .font(.system(size: 15))
                            .textContentType(.oneTimeCode)

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
                                    vm.signupPasswordError != nil ? Color.errorRed : Color(red: 0.90, green: 0.92, blue: 0.94),
                                    lineWidth: vm.signupPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.signupPasswordError)
                    }

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

                        HStack {
                            Group {
                                if isConfirmPasswordRevealed {
                                    TextField("........", text: $vm.signupConfirmPassword)
                                } else {
                                    SecureField("........", text: $vm.signupConfirmPassword)
                                }
                            }
                            .font(.system(size: 15))
                            .textContentType(.oneTimeCode)

                            Button(action: { isConfirmPasswordRevealed.toggle() }) {
                                Image(systemName: isConfirmPasswordRevealed ? "eye.slash" : "eye")
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
                                    vm.signupConfirmPasswordError != nil ? Color.errorRed : Color(red: 0.90, green: 0.92, blue: 0.94),
                                    lineWidth: vm.signupConfirmPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.signupConfirmPasswordError)
                    }

                    Spacer().frame(height: 8)

                    // Sign Up Button
                    Button(action: { vm.signUp() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.isSignupEnabled ? Color(red: 0.27, green: 0.51, blue: 0.96) : Color(red: 0.69, green: 0.82, blue: 1.0))

                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Up")
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

                // Switch to Login
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))

                    Button(action: { vm.switchToLogin() }) {
                        Text("Login")
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
        .alert("Sign Up Failed", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    SignupView(vm: AuthViewModel())
}
