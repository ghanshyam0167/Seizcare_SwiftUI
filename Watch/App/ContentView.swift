//
//  ContentView.swift
//  SeizcareWatch
//

import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        VStack {
            Image(systemName: "applewatch")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Seizcare Watch")
                .font(.headline)
            
            Divider().padding(.vertical)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Heart Rate: \(Int(connectivityManager.heartRate)) BPM")
                Text("Sleep: \(String(format: "%.1f", connectivityManager.sleepHours)) hrs")
            }
            .font(.caption)
        }
        .padding()
    }
}
