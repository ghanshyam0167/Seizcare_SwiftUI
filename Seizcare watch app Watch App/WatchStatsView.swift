//
//  WatchStatsView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct WatchStatsView: View {
    @ObservedObject var connectivity: WatchConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Health Data", systemImage: "heart.text.square.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("SpO2")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("98%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Sleep")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(String(format: "%.1f", connectivity.sleepHours)) hr")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}
