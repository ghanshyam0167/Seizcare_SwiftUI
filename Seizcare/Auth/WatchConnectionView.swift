//
//  WatchConnectionView.swift
//  Seizcare
//

import SwiftUI

struct WatchConnectionView: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRefreshing = false
    @State private var connectionStatus: WatchConnectionStatus = .notReachable
    
    enum WatchConnectionStatus {
        case notReachable
        case connected
    }
    
    private let statusColor = Color(red: 1.0, green: 0.72, blue: 0.0) // Premium Golden/Amber
    
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
                            
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .font(.system(size: 44))
                                .foregroundColor(statusColor)
                        }
                        .padding(.top, 8)
                        
                        VStack(spacing: 6) {
                            Text("Installed – Not Reachable")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                            
                            Text("Open the Seizcare app on your Apple Watch.")
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
        
        // Simulate a connection check delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isRefreshing = false
            // Here you would normally update the status based on WCSession
        }
    }
}

#Preview {
    WatchConnectionView(vm: AuthViewModel())
}
