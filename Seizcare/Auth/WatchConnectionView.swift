//
//  WatchConnectionView.swift
//  Seizcare
//

import SwiftUI
import WatchConnectivity

struct WatchConnectionView: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @State private var isRefreshing = false
    
    // Status color logic
    private var statusColor: Color {
        if !connectivity.isPaired { return .errorRed }
        if !connectivity.isReachable { return Color(red: 1.0, green: 0.72, blue: 0.0) } // Amber
        if !connectivity.isStreaming { return Color(red: 1.0, green: 0.72, blue: 0.0) } // Amber
        return .dashGreen
    }
    
    private var statusIcon: String {
        if !connectivity.isPaired { return "applewatch.slash" }
        if !connectivity.isReachable { return "applewatch.radiowaves.left.and.right" }
        if connectivity.isWaitingForFirstSample { return "rays" }
        return "applewatch.watchface"
    }
    
    private var statusTitle: String {
        if !connectivity.isPaired { return "No Watch Paired" }
        if !connectivity.isReachable { return "Installed – Not Reachable" }
        if connectivity.isWaitingForFirstSample { return "Verifying Stream..." }
        if !connectivity.isStreaming { return "Ready – Waiting for Data" }
        return "All set!"
    }
    
    private var statusDescription: String {
        if !connectivity.isPaired { return "Please pair an Apple Watch with your iPhone in the Watch app." }
        if !connectivity.isReachable { return "Open the Seizcare app on your Apple Watch to sync health data." }
        if connectivity.isWaitingForFirstSample { return "Received signal from Watch. Waiting for first heart rate sample..." }
        if !connectivity.isStreaming { return "Ensure the Seizcare app on your watch is active and streaming." }
        return "Your Apple Watch is connected and actively streaming health data."
    }
    
    private var statusSubtitleColor: Color {
        if connectivity.isReachable && connectivity.isPaired && connectivity.isStreaming { return .dashGreen }
        return Color(red: 1.0, green: 0.72, blue: 0.0) // Amber for others
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                
                Spacer()
                
                Text("Apple Watch")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Spacer()
                
                // Invisible spacer to balance the back button
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: statusIcon)
                                .font(.system(size: 44))
                                .foregroundColor(statusColor)
                                .rotationEffect(.degrees(connectivity.isWaitingForFirstSample ? 360 : 0))
                                .animation(connectivity.isWaitingForFirstSample ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: connectivity.isWaitingForFirstSample)
                            
                            if connectivity.isWaitingForFirstSample {
                                ProgressView()
                                    .tint(statusColor)
                                    .scaleEffect(1.2)
                            }
                        }
                        .padding(.top, 8)
                        
                        VStack(spacing: 6) {
                            Text(statusTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                            
                            Text(statusDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.authSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.authCardBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(statusColor.opacity(0.2), lineWidth: 1)
                    )
                    .authCardShadow()
                    
                    // Instructions Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How to connect")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.authPrimaryText)
                            .padding(.bottom, 4)
                        
                        instructionRow(number: 1, text: "Make sure your Apple Watch is nearby and unlocked.")
                        instructionRow(number: 2, text: "Open the Seizcare app on your Apple Watch.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(Color.authCardBackground)
                    .cornerRadius(20)
                    .authCardShadow()
                }
                .padding(24)
            }
            
            // Fixed Refresh Button
            Button(action: {
                refreshConnection()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.authPrimaryButton)
                        .frame(height: 56)
                    
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Refresh Status")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isRefreshing)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.authBackground.ignoresSafeArea())
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.authPrimaryButton)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.authSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
    
    private func refreshConnection() {
        isRefreshing = true
        
        // Re-activate session to trigger status delegates
        if WCSession.isSupported() {
            WCSession.default.activate()
        }
        
        // Simulate a connection check delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isRefreshing = false
        }
    }
}

#Preview {
    WatchConnectionView(vm: AuthViewModel())
}
