//
//  WatchAlarmActiveView.swift
//  Seizcare watch app Watch App
//

import SwiftUI
import WatchKit

struct WatchAlarmActiveView: View {
    @ObservedObject var connectivity = WatchConnectivityManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Pulsing background
            Color.red
                .ignoresSafeArea()
                .opacity(isAnimating ? 0.7 : 1.0)
            
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, options: .repeating)
                
                Text("EMERGENCY")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Alert Sent to Contacts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: {
                    WKInterfaceDevice.current().play(.stop)
                    connectivity.sendStopAlarmToPhone()
                }) {
                    Text("STOP ALARM")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            // Continuous haptic alert
            triggerHapticLoop()
        }
    }
    
    private func triggerHapticLoop() {
        guard connectivity.isAlarmActive else { return }
        
        WKInterfaceDevice.current().play(.notification)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.triggerHapticLoop()
        }
    }
}

#Preview {
    WatchAlarmActiveView()
}
