//
//  AlertCountdownView.swift
//  Seizcare watch app Watch App
//

import SwiftUI
import WatchKit
import Combine

struct AlertCountdownView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
    @State private var timeRemaining = 10
    @State private var progress: CGFloat = 1.0
    @State private var isAlertSent = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            (isAlertSent ? Color.green : Color.red)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 8) {
                if !isAlertSent {
                    countingUI
                } else {
                    sentUI
                }
            }
        }
        .onReceive(timer) { _ in
            if !isAlertSent {
                handleTimerTick()
            }
        }
        .onChange(of: connectivityManager.isAlarmActive) { isActive in
            // If alarm is stopped from phone while we are in counting or sent state, dismiss.
            if !isActive {
                print("[Watch] Alarm inactive on phone, dismissing Watch UI")
                dismiss()
            }
        }
    }
    
    private var countingUI: some View {
        VStack(spacing: 4) {
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
    
    private var sentUI: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
            
            Text("Alert Sent!")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Phone is alarming...")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: {
                connectivityManager.sendStopAlarmToPhone()
            }) {
                Text("Stop Alarm")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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
        print("🚨 Alert Sent from Watch")
        // SOS System Feedback
        WKInterfaceDevice.current().play(.failure)
        
        // Trigger alert via iPhone logic (this sets isAlarmActive = true)
        connectivityManager.triggerEmergencyAlert()
        
        // Immediate dismissal to let the global fullScreenCover in ContentView take over
        dismiss()
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
