//
//  SignupOTPView.swift
//  Seizcare
//

import SwiftUI
import Combine

struct SignupOTPView: View {
    @ObservedObject var vm: AuthViewModel
    
    @State private var timeRemaining = 60
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                CustomBackButton { vm.goBack() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 32)
            
            // Header
            VStack(spacing: 8) {
                Text("Verify Your Email")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("We've sent an 8-digit verification code to\n\(vm.signupEmail)")
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
                    Text("Verification Code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.authSecondaryText)
                    
                    TextField("12345678", text: $vm.signupOTP)
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
                    vm.verifySignupOTP()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vm.isSignupOTPEnabled ? Color.authPrimaryButton : Color.authButtonDisabled)
                        
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 52)
                }
                .disabled(vm.isLoading || !vm.isSignupOTPEnabled)
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
                    vm.signUp()
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

#Preview {
    ZStack {
        Color.authBackground.ignoresSafeArea()
        SignupOTPView(vm: AuthViewModel())
    }
}
