//
//  DemoAlertView.swift
//  Seizcare watch app Watch App
//

import SwiftUI
import WatchKit
import Combine

struct DemoAlertView: View {
    @EnvironmentObject var demoManager: DemoDetectionManager
    @State private var countdown: Int = 10
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .symbolEffect(.pulse)
            
            Text("SEIZURE\nDETECTED")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Text("Demo Mode")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.purple)
                .cornerRadius(4)
            
            Text("\(countdown)")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Button(action: {
                cancelDemo()
            }) {
                Text("Cancel")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .tint(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            WKInterfaceDevice.current().play(.notification)
        }
        .task {
            while countdown > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    countdown -= 1
                    WKInterfaceDevice.current().play(.notification)
                } catch {
                    break // Cancelled
                }
            }
            if countdown == 0 {
                // Countdown finished: send alert via WatchConnectivity
                WatchConnectivityManager.shared.sendDemoTrigger(hr: 0)
                cancelDemo()
            }
        }
    }
    
    private func cancelDemo() {
        demoManager.resetState()
    }
}
