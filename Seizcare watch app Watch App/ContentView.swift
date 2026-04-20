//
//  ContentView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @EnvironmentObject private var pipeline: DetectionPipelineManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Screen 2: SOS Alert (Now at Top)
                WatchAlertView()
                
                // Demo System Trigger
                if pipeline.demoMode {
                    Button(action: {
                        pipeline.forceSeizureTrigger = true
                        print("[UI] Demo Seizure Triggered")
                    }) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                            Text("Trigger Seizure")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .tint(.purple)
                }
                
                // Screen 1: Dashboard (Live HR)
                DashboardView(connectivity: connectivity)
                
                // Screen 4: Stats
                WatchStatsView(connectivity: connectivity)
                
                // Screen 3: Sensitivity
                WatchSensitivityView()
                
                // Screen 5: Controls
                WatchControlView(connectivity: connectivity)
            }
            .padding(.horizontal)
            

        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .fullScreenCover(isPresented: $connectivity.isAlarmActive) {
            WatchAlarmActiveView()
        }
    }
}

#Preview {
    ContentView()
}
