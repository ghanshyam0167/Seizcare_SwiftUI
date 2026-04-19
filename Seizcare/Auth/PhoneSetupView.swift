//
//  PhoneSetupView.swift
//  Seizcare
//

import SwiftUI

struct PhoneSetupView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { vm.goBack() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 30)
            
            // Header
            VStack(spacing: 8) {
                Text("phone_number".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("phone_number_desc".localized)
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer().frame(height: 60)
            
            // Phone Number Input
            VStack(alignment: .leading, spacing: 10) {
                Text("personal_contact".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.authSecondaryText)
                    .padding(.leading, 4)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14))
                        Text("+91")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.authPrimaryButton)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color.authPrimaryButton.opacity(0.1))
                    .cornerRadius(12)
                    
                    TextField("8929XXXXXX", text: $vm.onboardingPhoneNumber)
                        .keyboardType(.phonePad)
                        .font(.system(size: 18, design: .monospaced))
                }
                .padding()
                .background(Color.authFieldBackground)
                .cornerRadius(16)
                
                if !vm.onboardingPhoneNumber.isEmpty && vm.onboardingPhoneNumber.count != 10 {
                    Text("enter_10_digits".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.errorRed)
                        .padding(.leading, 4)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .onChange(of: vm.onboardingPhoneNumber) { _, newValue in
                // Only allow digits and max 10 characters
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count > 10 {
                    vm.onboardingPhoneNumber = String(filtered.prefix(10))
                } else if filtered != newValue {
                    vm.onboardingPhoneNumber = filtered
                }
            }
            
            Spacer()
            
            // Footer Action
            VStack(spacing: 16) {
                Button(action: {
                    vm.savePhoneAndContinue()
                }) {
                    let isValid = vm.onboardingPhoneNumber.isEmpty || vm.onboardingPhoneNumber.count == 10
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isValid ? Color.authPrimaryButton : Color.authButtonDisabled)
                            .frame(height: 56)
                        
                        Text(vm.onboardingPhoneNumber.isEmpty ? "skip".localized : "next".localized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!vm.onboardingPhoneNumber.isEmpty && vm.onboardingPhoneNumber.count != 10)
                
                if !vm.onboardingPhoneNumber.isEmpty {
                    Button(action: {
                        vm.onboardingPhoneNumber = ""
                        vm.savePhoneAndContinue()
                    }) {
                        Text("ill_do_this_later".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.authSecondaryText)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
}

#Preview {
    PhoneSetupView(vm: AuthViewModel())
}
