//
//  OnboardingView.swift
//  Seizcare
//
//  Three step onboarding screen shown to new users.
//

import SwiftUI

// MARK: - OnboardingPage Model

struct OnboardingPage {
    let id = UUID()
    let title: String
    let subtitle: String
}

let onboardingPages = [
    OnboardingPage(
        title: "Stay Safe, Stay Aware",
        subtitle: "Seizcare helps monitor and assist you or your loved ones during seizures, keeping everyone informed."
    ),
    OnboardingPage(
        title: "Smart Monitoring",
        subtitle: "Track patterns and get alerts in real time, so you're always one step ahead."
    ),
    OnboardingPage(
        title: "Get Started",
        subtitle: "Create your account to begin monitoring and stay protected around the clock."
    )
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject var vm: AuthViewModel
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.961, green: 0.969, blue: 0.984).ignoresSafeArea()
            
            VStack {

                // Paging View
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // Visuals per page
                            Group {
                                if index == 0 {
                                    IllustrationStaySafe()
                                } else if index == 1 {
                                    IllustrationSmartMonitoring()
                                } else {
                                    IllustrationGetStarted()
                                }
                            }
                            .frame(height: 250)
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(onboardingPages[index].title)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.18))
                                
                                Text(onboardingPages[index].subtitle)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Color(red: 0.48, green: 0.53, blue: 0.62))
                                    .lineSpacing(4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            
                            // Second page has a list
                            if index == 1 {
                                VStack(alignment: .leading, spacing: 16) {
                                    FeatureRow(icon: "shield", text: "Automatic seizure detection")
                                    FeatureRow(icon: "bell", text: "Instant emergency alerts")
                                    FeatureRow(icon: "chart.bar.fill", text: "Pattern tracking & reports")
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Bottom Controls
                VStack(spacing: 24) {
                    // Custom Pagination Dots
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            if index == currentPage {
                                Capsule()
                                    .fill(Color(red: 0.27, green: 0.51, blue: 0.96))
                                    .frame(width: 24, height: 8)
                            } else {
                                Circle()
                                    .fill(Color(red: 0.81, green: 0.85, blue: 0.91))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    // Buttons
                    if currentPage == 2 {
                        VStack(spacing: 12) {
                            Button(action: { vm.switchToSignup() }) {
                                Text("Sign Up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color(red: 0.27, green: 0.51, blue: 0.96))
                                    .cornerRadius(16)
                            }
                            
                            Button(action: { vm.switchToLogin() }) {
                                Text("Login")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.08, green: 0.11, blue: 0.18))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.white) // Using a light/gray/white look
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.27, green: 0.51, blue: 0.96))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Illustrations & Components

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // Assuming standard SFSymbols which are slightly small by default
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.27, green: 0.51, blue: 0.96))
            }
            .frame(width: 32, height: 32)
            .background(Color(red: 0.961, green: 0.969, blue: 0.984)) // Blend with background
            .overlay(
                 Circle().stroke(Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
            )
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.18, green: 0.23, blue: 0.32))
        }
    }
}

struct IllustrationStaySafe: View {
    var body: some View {
        ZStack {
            // Background concentric circles
            Circle().fill(Color.blue.opacity(0.03)).frame(width: 220)
            Circle().fill(Color.blue.opacity(0.06)).frame(width: 160)
            
            // Outer small dots connected by faint lines if they were in an image
            Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 12).offset(x: -80, y: -40)
            Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 16).offset(x: 70, y: -50)
            Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 14).offset(x: -60, y: 70)
            Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 18).offset(x: 80, y: 60)
            
            // Center element
            ZStack {
                Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 100)
                Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 60)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color(red: 0.27, green: 0.51, blue: 0.96))
            }
        }
    }
}

struct IllustrationSmartMonitoring: View {
    var body: some View {
        ZStack {
            // Outer small dots
            Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 24).offset(x: -80, y: -20)
            Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 14).offset(x: 100, y: 30)
            
            // Center checkmark
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 0.45, green: 0.65, blue: 0.98))
                .font(.system(size: 20))
                .offset(y: -70)
                
            // Main card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.88, green: 0.93, blue: 0.99))
                .frame(width: 160, height: 100)
            
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Color(red: 0.45, green: 0.65, blue: 0.98)).frame(width: 80, height: 8)
                Capsule().fill(Color(red: 0.70, green: 0.85, blue: 1.0)).frame(width: 60, height: 8)
                
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 36, height: 16)
                    Capsule().fill(Color(red: 0.70, green: 0.85, blue: 1.0)).frame(width: 40, height: 4)
                }
            }
        }
    }
}

struct IllustrationGetStarted: View {
    var body: some View {
        ZStack {
            // Background subtle stuff
            Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 16).offset(x: -70, y: -40)
            Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 20).offset(x: 80, y: -30)
            Circle().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 18).offset(x: -50, y: 70)
            Circle().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 24).offset(x: 90, y: 60)
            
            // Main document
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 120, height: 140)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 12) {
                    Capsule().fill(Color(red: 0.65, green: 0.77, blue: 0.98)).frame(width: 60, height: 8)
                    Capsule().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 80, height: 6)
                    Capsule().fill(Color(red: 0.85, green: 0.90, blue: 0.98)).frame(width: 70, height: 6)
                }
                .offset(y: -15)
            }
            
            // Big Checkmark overlap
            ZStack {
                Circle()
                    .fill(Color(red: 0.27, green: 0.51, blue: 0.96))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .bold))
            }
            .offset(x: 0, y: 60)
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(vm: AuthViewModel())
}
