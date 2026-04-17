//
//  LanguageSetupView.swift
//  Seizcare
//

import SwiftUI

struct AppLanguageUI: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let iconChar: String
}

struct LanguageSetupView: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // We'll use this just to highlight the selection in the UI
    @State private var selectedLanguageId: String = "en"
    
    private let languages: [AppLanguageUI] = [
        AppLanguageUI(id: "en", title: "English", subtitle: "Default", iconChar: "A"),
        AppLanguageUI(id: "hi", title: "हिंदी", subtitle: "Hindi", iconChar: "अ"),
        AppLanguageUI(id: "bn", title: "বাংলা", subtitle: "Bengali", iconChar: "অ"),
        AppLanguageUI(id: "te", title: "తెలుగు", subtitle: "Telugu", iconChar: "అ"),
        AppLanguageUI(id: "mr", title: "मराठी", subtitle: "Marathi", iconChar: "म"),
        AppLanguageUI(id: "ta", title: "தமிழ்", subtitle: "Tamil", iconChar: "அ")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: { 
                    dismiss()
                }) {
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
            
            Spacer().frame(height: 10)
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.authPrimaryButton)
                    .padding(.bottom, 8)
                
                Text("Select Language")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("Choose your preferred language for the application interface.")
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
                    ForEach(languages) { language in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedLanguageId = language.id
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(selectedLanguageId == language.id ? Color.authPrimaryButton.opacity(0.15) : Color.white.opacity(0.05))
                                        .frame(width: 48, height: 48)
                                    
                                    Text(language.iconChar)
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(selectedLanguageId == language.id ? .authPrimaryButton : .authSecondaryText)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(selectedLanguageId == language.id ? .authPrimaryButton : .authPrimaryText)
                                    
                                    Text(language.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.authSecondaryText)
                                }
                                
                                Spacer()
                                
                                if selectedLanguageId == language.id {
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
                                        .fill(selectedLanguageId == language.id ? Color.authPrimaryButton.opacity(0.05) : Color.authCardBackground)
                                    
                                    if selectedLanguageId == language.id {
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
                    
                    Text("Done")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 10)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
}

#Preview {
    LanguageSetupView(vm: AuthViewModel())
}
