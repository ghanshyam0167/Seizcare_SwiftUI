//
//  DashboardView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var connectivity: WatchConnectivityManager
    @State private var pulse = false
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(connectivity.isStreaming ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(pulse && connectivity.isStreaming ? 0.3 : 1.0)
                    .animation(connectivity.isStreaming ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: pulse)
                
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .onAppear { pulse = true }
            
            Spacer().frame(height: 10)
            
            Text(connectivity.displayHeartRateText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(connectivity.hasHeartRateValue ? .green : .secondary.opacity(0.5))
                .transition(.opacity)
            
            Text("BPM")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("Heart Rate")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
    
    private var statusText: String {
        if !connectivity.isStreaming { return "STOPPED" }
        return connectivity.hasHeartRateValue ? "LIVE" : "WAITING"
    }
}
