//
//  ForgotPasswordEmailView.swift
//  Seizcare
//

import SwiftUI

struct ForgotPasswordEmailView: View {
    @ObservedObject var vm: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            if vm.isAuthenticated {
                HStack {
                    Button(action: { vm.cancelForgotPasswordAndReturn() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.authPrimaryText)
                            .padding(12)
                            .background(Color.authCardBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            } else {
                Spacer().frame(height: 60)
            }

            // Header
            VStack(spacing: 8) {
                Text("reset_password")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)

                Text("reset_password_desc")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 32)

            // Form Card
            VStack(spacing: 16) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("email")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.authSecondaryText)

                    TextField("your@email.com", text: $vm.forgotPasswordEmail)
                        .font(.system(size: 15))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.authFieldBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    vm.forgotPasswordEmailError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.forgotPasswordEmailError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.forgotPasswordEmailError)
                }

                Spacer().frame(height: 8)

                // Submit Button
                Button(action: { vm.sendPasswordReset() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vm.isForgotPasswordEmailEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)

                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("send_code")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 52)
                }
                .disabled(vm.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.authCardBackground)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            Button(action: { vm.cancelForgotPasswordAndReturn() }) {
                Text(vm.isAuthenticated ? "cancel" : "back_to_login")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.authPrimaryButton)
            }
            .padding(.bottom, 8)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}
