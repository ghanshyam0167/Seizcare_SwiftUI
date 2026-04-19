//
//  LanguageSetupView.swift
//  Seizcare
//

import SwiftUI

struct LanguageSetupView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 10)
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.authPrimaryButton)
                    .padding(.bottom, 8)
                
                Text("select_language".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("select_language_desc".localized)
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            
            Spacer().frame(height: 32)
            
            // Selection Options
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(languageManager.languages) { language in
                        Button(action: {
                            languageManager.setLanguage(language.code)
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(languageManager.currentLanguage == language.code ? Color.authPrimaryButton.opacity(0.15) : Color.white.opacity(0.05))
                                        .frame(width: 48, height: 48)
                                    
                                    Text(String(language.nativeName.prefix(1)))
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(languageManager.currentLanguage == language.code ? .authPrimaryButton : .authSecondaryText)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.nativeName)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(languageManager.currentLanguage == language.code ? .authPrimaryButton : .authPrimaryText)
                                    
                                    Text(language.englishName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.authSecondaryText)
                                }
                                
                                Spacer()
                                
                                if languageManager.currentLanguage == language.code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.authPrimaryButton)
                                        .font(.system(size: 22))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(16)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(languageManager.currentLanguage == language.code ? Color.authPrimaryButton.opacity(0.05) : Color.authCardBackground)
                                    
                                    if languageManager.currentLanguage == language.code {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.authPrimaryButton.opacity(0.3), lineWidth: 2)
                                    }
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            
            // Footer Action
            Button(action: { dismiss() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.authPrimaryButton)
                        .frame(height: 56)
                    
                    Text("done".localized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 10)
        }
        .background(Color.authBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    LanguageSetupView(vm: AuthViewModel())
        .environmentObject(LanguageManager())
}
