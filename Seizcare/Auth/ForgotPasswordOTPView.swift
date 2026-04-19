//
//  ForgotPasswordOTPView.swift
//  Seizcare
//

import SwiftUI
import Combine

struct ForgotPasswordOTPView: View {
    @ObservedObject var vm: AuthViewModel
    
    @State private var timeRemaining = 60
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
                Text("Verification Code")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("We've sent an 8-digit code to\n\(vm.forgotPasswordEmail)")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
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
                        .foregroundColor(.authSecondaryText)
                    
                    TextField("12345678", text: $vm.forgotPasswordOTP)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .frame(height: 52)
                        .background(Color.authFieldBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.authInputBorder, lineWidth: 1)
                        )
                }
                
                Spacer().frame(height: 8)
                
                // Submit Button
                Button(action: {
                    vm.verifyResetOTP()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vm.isForgotPasswordOTPEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)
                        
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
            .background(Color.authCardBackground)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 24)
            
            HStack(spacing: 4) {
                Text("Didn't receive code?")
                    .font(.system(size: 14))
                    .foregroundColor(.authSecondaryText)
                
                Button(action: { 
                    vm.sendPasswordReset() 
                    timeRemaining = 60
                }) {
                    Text(timeRemaining > 0 ? "Resend in \(timeRemaining)s" : "Resend")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(timeRemaining > 0 ? .authSecondaryText.opacity(0.5) : Color.authPrimaryButton)
                }
                .disabled(timeRemaining > 0)
            }
            Spacer()
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
}
