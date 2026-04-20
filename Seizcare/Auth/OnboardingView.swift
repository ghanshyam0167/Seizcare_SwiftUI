//
//  OnboardingView.swift
//  Seizcare
//
//  Single-screen onboarding shown to new users.
//

import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        ZStack {
            Color.authBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 88)
                
                HStack {
                    Spacer()
                    AuthLogoMark(size: 150)
                    Spacer()
                }
                .padding(.bottom, 44)
                
                Text("welcome_to_seizcare".localized)
                    .font(.appTitle)
                    .foregroundColor(.authPrimaryText)
                    .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(
                        icon: "waveform.path.ecg",
                        title: "onboarding_detection_title".localized,
                        subtitle: "onboarding_detection_subtitle".localized
                    )
                    FeatureRow(
                        icon: "bell",
                        title: "onboarding_alert_title".localized,
                        subtitle: "onboarding_alert_subtitle".localized
                    )
                    FeatureRow(
                        icon: "doc.text",
                        title: "onboarding_records_title".localized,
                        subtitle: "onboarding_records_subtitle".localized
                    )
                }
                
                Spacer()
                
                Button(action: { vm.switchToSignup() }) {
                    Text("continue".localized)
                        .font(.appHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.authPrimaryButton)
                        .cornerRadius(16)
                }
                .padding(.top, 28)
                
                Button(action: { vm.switchToLogin() }) {
                    Text("login".localized)
                        .font(.appSubheadline)
                        .foregroundColor(.authPrimaryButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Illustrations & Components

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.appHeadline)
                .foregroundColor(Color.authPrimaryButton)
                .frame(width: 30, height: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appHeadline)
                    .foregroundColor(.authPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.appBody)
                    .foregroundColor(.authSecondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(vm: AuthViewModel())
}
