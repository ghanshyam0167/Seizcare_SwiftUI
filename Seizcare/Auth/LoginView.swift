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
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                AuthLogoMark(size: 112)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)

                // Header
                Text("welcome_back".localized)
                    .font(.appLargeTitle)
                    .foregroundColor(.authPrimaryText)

                Text("login_to_continue".localized)
                    .font(.appBody)
                    .foregroundColor(.authSecondaryText)
                    .padding(.top, 8)

                Spacer().frame(height: 24)

                // Form Card
                VStack(spacing: 16) {

                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("email".localized)
                            .font(.appFootnote)
                            .foregroundColor(.authSecondaryText)

                        ZStack(alignment: .leading) {
                            if vm.loginEmail.isEmpty {
                                Text("you@example.com")
                                    .font(.appCallout)
                                    .foregroundColor(.authPlaceholderText)
                                    .padding(.horizontal, 16)
                                    .allowsHitTesting(false)
                            }

                            TextField("", text: $vm.loginEmail)
                                .font(.appCallout)
                                .foregroundColor(.authPrimaryText)
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .animation(.easeInOut(duration: 0.2), value: vm.loginEmailError)
                        }
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
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("password".localized)
                            .font(.appFootnote)
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isPasswordRevealed {
                                    TextField("........", text: $vm.loginPassword)
                                } else {
                                    SecureField("........", text: $vm.loginPassword)
                                }
                            }
                            .font(.appCallout)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .password)

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
                                .font(.appSubheadline)
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
                                    .font(.appHeadline)
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
                        .font(.appSubheadline)
                        .foregroundColor(.authSecondaryText)

                    Button(action: { vm.switchToSignup() }) {
                        Text("sign_up".localized)
                            .font(.appSubheadline)
                            .foregroundColor(Color.authPrimaryButton)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    if value.translation.height > 8 {
                        dismissKeyboard()
                    }
                }
        )
        .onTapGesture {
            dismissKeyboard()
        }
        .alert("login_failed".localized, isPresented: $vm.showAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
    }
    
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview

#Preview {
    LoginView(vm: AuthViewModel())
}
