//
//  WatchDemoModeView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct WatchDemoModeView: View {
    @EnvironmentObject var demoManager: DemoDetectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $demoManager.isEnabled) {
                Text("Demo Mode")
                    .font(.headline)
                    .foregroundColor(demoManager.isEnabled ? .purple : .primary)
            }
            .tint(.purple)
            
            Text("Motion-Based Demo Only")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text("No real detection. No health data.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            if demoManager.isEnabled {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(demoManager.currentStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor(for: demoManager.currentStatus))
                        .animation(.easeInOut, value: demoManager.currentStatus)
                    
                    HStack {
                        Text("Intensity:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f", demoManager.smoothedIntensity))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(demoManager.smoothedIntensity > 2.5 ? .orange : .white)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color.purple.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }
    
    private func statusColor(for status: DemoStatus) -> Color {
        switch status {
        case .monitoring:
            return .green
        case .highMovement:
            return .orange
        case .alertTriggered:
            return .red
        }
    }
}
