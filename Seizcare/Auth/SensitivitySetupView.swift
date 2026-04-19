//
//  SensitivitySetupView.swift
//  Seizcare
//

import SwiftUI
import Combine

struct SensitivitySetupView: View {
    @ObservedObject var vm: AuthViewModel
    @ObservedObject private var sensitivityModel = SensitivityDataModel.shared
    @Environment(\.dismiss) private var dismiss
    
    // We use a local state to track current selection for smooth UI interactions
    @State private var localSelection: SensitivityLevel = .medium
    
    private let options: [(level: SensitivityLevel, title: String, description: String, icon: String)] = [
        (.low, "Low Sensitivity", "Minimized false alerts. Use if you are highly active.", "figure.run"),
        (.medium, "Medium (Default)", "Balanced detection. Recommended for most daily routines.", "figure.walk"),
        (.high, "High Sensitivity", "Maximum vigilance. Best for periods of rest or high risk.", "figure.skating")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton {
                    if vm.isAuthenticated {
                        dismiss()
                    } else {
                        vm.goBack() 
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 10)
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 48))
                    .foregroundColor(.authPrimaryButton)
                    .padding(.bottom, 8)
                
                Text("Detection Sensitivity")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("Choose how sensitive the movement detection should be for seizure alerts.")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            
            Spacer().frame(height: 40)
            
            // Selection Options
            VStack(spacing: 16) {
                ForEach(options, id: \.level) { option in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            localSelection = option.level
                        }
                        // Save immediately so selection persists if user navigates back
                        sensitivityModel.setSensitivity(level: option.level)
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(localSelection == option.level ? Color.authPrimaryButton.opacity(0.15) : Color.white.opacity(0.05))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: option.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(localSelection == option.level ? .authPrimaryButton : .authSecondaryText)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(localSelection == option.level ? .authPrimaryButton : .authPrimaryText)
                                
                                Text(option.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.authSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            // Fixed width container prevents layout shifts when checkmark appears/disappears
                            ZStack(alignment: .trailing) {
                                if localSelection == option.level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.authPrimaryButton)
                                        .font(.system(size: 22))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .frame(width: 24)
                        }
                        .padding(16)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(localSelection == option.level ? Color.authPrimaryButton.opacity(0.05) : Color.authCardBackground)
                                
                                if localSelection == option.level {
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
            
            Spacer()
            
            // Info Note
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.authSecondaryText)
                Text("You can change this anytime in settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.authSecondaryText)
            }
            .padding(.bottom, 24)
            
            // Footer Action
            Button(action: {
                if vm.isAuthenticated {
                    dismiss()
                } else {
                    vm.completeSensitivitySetup()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.authPrimaryButton)
                        .frame(height: 56)
                    
                    Text(vm.isAuthenticated ? "Done" : "Next")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Set immediately from cached value — no flicker
            localSelection = sensitivityModel.currentSensitivity
            // Then fetch from Supabase and update if different
            Task {
                await sensitivityModel.refreshSensitivity()
            }
        }
        // Keep localSelection in sync as model updates from Supabase
        .onChange(of: sensitivityModel.currentSensitivity) { _, newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                localSelection = newValue
            }
        }
    }
}

#Preview {
    ZStack {
        Color.authBackground.ignoresSafeArea()
        SensitivitySetupView(vm: AuthViewModel())
    }
}
