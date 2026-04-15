//
//  ForgotPasswordOTPView.swift
//  Seizcare
//

import SwiftUI

struct ForgotPasswordOTPView: View {
    @ObservedObject var vm: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
            // Header
            VStack(spacing: 8) {
                Text("Verification Code")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("We've sent an 8-digit code to\n\(vm.forgotPasswordEmail)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
            
            Spacer().frame(height: 32)
            
            // Form Card
            VStack(spacing: 16) {
                // OTP Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("OTP Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
                    
                    TextField("12345678", text: $vm.forgotPasswordOTP)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
                        )
                }
                
                Spacer().frame(height: 8)
                
                // Submit Button
                Button(action: {
                    vm.verifyResetOTP()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vm.isForgotPasswordOTPEnabled ? Color(red: 0.27, green: 0.51, blue: 0.96) : Color(red: 0.69, green: 0.82, blue: 1.0))
                        
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify Code")
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
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 24)
            
            HStack(spacing: 4) {
                Text("Didn't receive code?")
                    .font(.system(size: 14))
                    .foregroundColor(.authSecondaryText)
                
                Button(action: { vm.sendPasswordReset() }) {
                    Text("Resend")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.27, green: 0.51, blue: 0.96))
                }
            }
            
            // Back to Login switch
            Button(action: { vm.switchToLogin() }) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
            }
            .padding(.vertical, 16)
            
            Spacer()
        }
    }
}
