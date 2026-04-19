//
//  SelectLanguageView.swift
//  Seizcare
//

import SwiftUI

struct SelectLanguageView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    let languages = [
        AppLanguage(code: "en", nativeName: "English", englishName: "English"),
        AppLanguage(code: "hi", nativeName: "हिंदी", englishName: "Hindi"),
        AppLanguage(code: "bn", nativeName: "বাংলা", englishName: "Bengali"),
        AppLanguage(code: "te", nativeName: "తెలుగు", englishName: "Telugu"),
        AppLanguage(code: "mr", nativeName: "मराठी", englishName: "Marathi"),
        AppLanguage(code: "ta", nativeName: "தமிழ்", englishName: "Tamil")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
            // Header
            VStack(spacing: 8) {
                Text("select_language".localized)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("select_language_desc".localized)
                    .font(.system(size: 16))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer().frame(height: 48)
            
            // Language List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(languages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: languageManager.currentLanguage == language.code
                        ) {
                            languageManager.setLanguage(language.code)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            Spacer()
            
            // Footer Action
            Button(action: {
                withAnimation(.spring()) {
                    vm.activeScreen = .onboarding
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.authPrimaryButton)
                        .frame(height: 56)
                    
                    Text("done".localized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
}

private struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.nativeName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? .authPrimaryButton : .authPrimaryText)
                    
                    Text(language.englishName)
                        .font(.system(size: 14))
                        .foregroundColor(.authSecondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.authPrimaryButton)
                        .font(.system(size: 24))
                } else {
                    Circle()
                        .stroke(Color.authInputBorder, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.authPrimaryButton.opacity(0.05) : Color.authCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.authPrimaryButton.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SelectLanguageView(vm: AuthViewModel())
        .environmentObject(LanguageManager())
}
