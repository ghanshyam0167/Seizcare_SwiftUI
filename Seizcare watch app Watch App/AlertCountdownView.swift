//
//  AlertCountdownView.swift
//  Seizcare watch app Watch App
//

import SwiftUI
import WatchKit
import Combine

struct AlertCountdownView: View {
    @Environment(\.dismiss) var dismiss
    @State private var timeRemaining = 10
    @State private var progress: CGFloat = 1.0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            Color.red
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Emergency Alert")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Countdown Circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: progress)
                    
                    Text("\(timeRemaining)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .padding(.vertical, 4)
                
                // Bottom Button
                Button(action: {
                    stopAndDismiss(cancelled: true)
                }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        }
        .onReceive(timer) { _ in
            handleTimerTick()
        }
    }
    
    private func handleTimerTick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
            progress = CGFloat(timeRemaining) / 10.0
            
            // Haptic click every second
            WKInterfaceDevice.current().play(.click)
            
            if timeRemaining == 0 {
                triggerAlert()
            }
        }
    }
    
    private func triggerAlert() {
        print("🚨 Alert Sent")
        // SOS System Feedback (Haptics only on Watch per user request)
        WKInterfaceDevice.current().play(.failure) // Jarring vibration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WKInterfaceDevice.current().play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            WKInterfaceDevice.current().play(.notification)
        }
        
        // Trigger alert via iPhone logic
        WatchConnectivityManager.shared.triggerEmergencyAlert()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            stopAndDismiss(cancelled: false)
        }
    }
    
    private func stopAndDismiss(cancelled: Bool) {
        if cancelled {
            print("❌ Alert Cancelled")
        }
        dismiss()
    }
}

#Preview {
    AlertCountdownView()
}
