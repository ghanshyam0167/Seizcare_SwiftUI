//
//  ChangePasswordView.swift
//  Seizcare
//
//  Created to handle secure in-app password changes.
//

import SwiftUI

struct ChangePasswordView: View {
    @ObservedObject var vm: AuthViewModel
    
    @State private var isCurrentRevealed = false
    @State private var isNewRevealed = false
    @State private var isConfirmRevealed = false

    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: { 
                        vm.isChangePasswordPresented = false
                        vm.changeCurrentPassword = ""
                        vm.changeNewPassword = ""
                        vm.changeConfirmPassword = ""
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.authPrimaryText)
                            .padding(12)
                            .background(Color.authCardBackground)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("change_password")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.authPrimaryText)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 42, height: 42)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer().frame(height: 24)

                // Header
                Text("update_password")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                    .padding(.horizontal, 24)

                Text("update_password_desc")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.authSecondaryText)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                // Form Card
                VStack(spacing: 16) {
                    
                    // Current Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("current_password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isCurrentRevealed {
                                    TextField("........", text: $vm.changeCurrentPassword)
                                } else {
                                    SecureField("........", text: $vm.changeCurrentPassword)
                                }
                            }
                            .font(.system(size: 15))

                            Button(action: { isCurrentRevealed.toggle() }) {
                                Image(systemName: isCurrentRevealed ? "eye.slash" : "eye")
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
                                    vm.changeCurrentPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.changeCurrentPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.changeCurrentPasswordError)
                    }

                    // New Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("new_password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isNewRevealed {
                                    TextField("........", text: $vm.changeNewPassword)
                                } else {
                                    SecureField("........", text: $vm.changeNewPassword)
                                }
                            }
                            .font(.system(size: 15))

                            Button(action: { isNewRevealed.toggle() }) {
                                Image(systemName: isNewRevealed ? "eye.slash" : "eye")
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
                                    vm.changeNewPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.changeNewPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.changeNewPasswordError)
                    }

                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("confirm_new_password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.authSecondaryText)

                        HStack {
                            Group {
                                if isConfirmRevealed {
                                    TextField("........", text: $vm.changeConfirmPassword)
                                } else {
                                    SecureField("........", text: $vm.changeConfirmPassword)
                                }
                            }
                            .font(.system(size: 15))

                            Button(action: { isConfirmRevealed.toggle() }) {
                                Image(systemName: isConfirmRevealed ? "eye.slash" : "eye")
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
                                    vm.changeConfirmPasswordError != nil ? Color.errorRed : Color.authInputBorder,
                                    lineWidth: vm.changeConfirmPasswordError != nil ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: vm.changeConfirmPasswordError)
                    }

                    // Forgot password?
                    HStack {
                        Spacer()
                        Button(action: {
                            vm.isChangePasswordPresented = false
                            vm.startInAppForgotPassword()
                        }) {
                            Text("forgot_password_question")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.authPrimaryButton)
                        }
                    }

                    Spacer().frame(height: 4)

                    // Update Password Button
                    Button(action: { vm.changePassword() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.isChangePasswordEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)

                            if vm.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("update_password")
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
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Update Failed", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    ChangePasswordView(vm: AuthViewModel())
}
