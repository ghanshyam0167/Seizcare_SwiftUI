//
//  WatchAlertView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct WatchAlertView: View {
    @State private var isAnimating = false
    @State private var showingCountdown = false
    
    var body: some View {
        Button(action: {
            showingCountdown = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Alert")
                        .font(.headline)
                    Text("Emergency SOS")
                        .font(.system(size: 10))
                        .opacity(0.8)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red)
                    .opacity(isAnimating ? 0.9 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .fullScreenCover(isPresented: $showingCountdown) {
            AlertCountdownView()
        }
    }
}
