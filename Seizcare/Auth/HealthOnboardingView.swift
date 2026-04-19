//
//  HealthOnboardingView.swift
//  Seizcare
//

import SwiftUI

struct HealthOnboardingView: View {
    @ObservedObject var vm: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager

    let frequencies: [(String, String)] = [
        ("daily", "daily"),
        ("weekly", "weekly"),
        ("monthly", "monthly"),
        ("rarely", "rarely")
    ]
    let sleepOptions: [(String, String)] = [
        ("less_than_4_hours", "less_than_4_hours"),
        ("4_to_6_hours", "4_to_6_hours"),
        ("6_to_8_hours", "6_to_8_hours"),
        ("more_than_8_hours", "more_than_8_hours")
    ]
    let durations: [(String, String)] = [
        ("less_than_1_min", "less_than_1_min"),
        ("1_to_3_mins", "1_to_3_mins"),
        ("3_to_5_mins", "3_to_5_mins"),
        ("more_than_5_mins", "more_than_5_mins")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { vm.goBack() }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("complete_profile".localized)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.authPrimaryText)
                        
                        Text("personalize_profile_footer_desc".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.authSecondaryText)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Average Sleep
                    VStack(alignment: .leading, spacing: 12) {
                        Text("avg_sleep_night".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(sleepOptions, id: \.0) { option in
                                SelectionPill(
                                    title: option.1,
                                    isSelected: vm.onboardingAvgSleep == option.0
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingAvgSleep = vm.onboardingAvgSleep == option.0 ? "" : option.0
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Seizure Frequency
                    VStack(alignment: .leading, spacing: 12) {
                        Text("estimated_frequency".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(frequencies, id: \.0) { option in
                                SelectionPill(
                                    title: option.1,
                                    isSelected: vm.onboardingFrequency == option.0
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingFrequency = vm.onboardingFrequency == option.0 ? "" : option.0
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Average Duration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("avg_duration".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(durations, id: \.0) { option in
                                SelectionPill(
                                    title: option.1,
                                    isSelected: vm.onboardingAvgDuration == option.0
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingAvgDuration = vm.onboardingAvgDuration == option.0 ? "" : option.0
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 40)
                }
            }

            // Footer
            VStack(spacing: 16) {
                let isComplete = !vm.onboardingAvgSleep.isEmpty && !vm.onboardingFrequency.isEmpty && !vm.onboardingAvgDuration.isEmpty
                AuthPrimaryButton(title: "finish_setup", isLoading: vm.isLoading, isEnabled: isComplete) {
                    vm.completeHealthOnboarding()
                }
            }
            .padding(24)
            .background(Color.authBackground)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
}

private struct SelectionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(isSelected ? .white : .authPrimaryText)
                .background(
                    isSelected
                    ? Color.brandPrimary
                    : Color.authFieldBackground
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.authInputBorder,
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? Color.brandPrimary.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    HealthOnboardingView(vm: AuthViewModel())
}
