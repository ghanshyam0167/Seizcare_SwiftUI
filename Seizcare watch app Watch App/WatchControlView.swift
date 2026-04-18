//
//  WatchControlView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct WatchControlView: View {
    @ObservedObject var connectivity: WatchConnectivityManager
    
    var body: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 4)
            
            Button(action: {
                if connectivity.isStreaming {
                    connectivity.stopStreaming()
                } else {
                    connectivity.startStreaming()
                }
            }) {
                HStack {
                    Image(systemName: connectivity.isStreaming ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundStyle(connectivity.isStreaming ? .red : .green)
                    Text(connectivity.isStreaming ? "Stop Stream" : "Start Stream")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background((connectivity.isStreaming ? Color.red : Color.green).opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Text(connectivity.isStreaming ? "Ends live data collection from iPhone" : "Resumes live data collection from iPhone")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
    }
}
