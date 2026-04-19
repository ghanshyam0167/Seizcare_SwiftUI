//
//  HealthOnboardingView.swift
//  Seizcare
//

import SwiftUI

struct HealthOnboardingView: View {
    @ObservedObject var vm: AuthViewModel

    let frequencies = ["Daily", "Weekly", "Monthly", "Rarely"]
    let sleepOptions = ["< 4 hours", "4-6 hours", "6-8 hours", "> 8 hours"]
    let durations = ["< 1 min", "1-3 mins", "3-5 mins", "> 5 mins"]

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
                        Text("Personalize Your Profile")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.authPrimaryText)
                        
                        Text("This info helps us tailor insights over time. It won't appear on your charts.")
                            .font(.system(size: 15))
                            .foregroundColor(.authSecondaryText)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Average Sleep
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Average Sleep per Night")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(sleepOptions, id: \.self) { option in
                                SelectionPill(
                                    title: option,
                                    isSelected: vm.onboardingAvgSleep == option
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingAvgSleep = vm.onboardingAvgSleep == option ? "" : option
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Seizure Frequency
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimated Frequency")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(frequencies, id: \.self) { option in
                                SelectionPill(
                                    title: option,
                                    isSelected: vm.onboardingFrequency == option
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingFrequency = vm.onboardingFrequency == option ? "" : option
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Average Duration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Average Duration")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.authPrimaryText)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(durations, id: \.self) { option in
                                SelectionPill(
                                    title: option,
                                    isSelected: vm.onboardingAvgDuration == option
                                ) {
                                    withAnimation(.spring()) {
                                        vm.onboardingAvgDuration = vm.onboardingAvgDuration == option ? "" : option
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
                AuthPrimaryButton(title: "Complete Setup", isLoading: vm.isLoading, isEnabled: isComplete) {
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
            Text(title)
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
