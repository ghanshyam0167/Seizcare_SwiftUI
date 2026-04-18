//
//  WatchSensitivityView.swift
//  Seizcare watch app Watch App
//

import SwiftUI

struct WatchSensitivityView: View {
    @State private var sensitivity: Int = 2 // 0: Low, 1: Medium, 2: High
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sensitivity")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    Button(action: { sensitivity = index }) {
                        segmentedButton(for: index)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 2)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(3)
                .padding(.top, 4)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var description: String {
        switch sensitivity {
        case 0: return "Detects only major movements."
        case 1: return "Balanced detection for standard activity."
        case 2: return "Highly sensitive, detects even mild activity."
        default: return ""
        }
    }
    
    private func label(for index: Int) -> String {
        switch index {
        case 0: return "Low"
        case 1: return "Med"
        case 2: return "High"
        default: return ""
        }
    }
    
    @ViewBuilder
    private func segmentedButton(for index: Int) -> some View {
        Text(label(for: index))
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(sensitivity == index ? Color.blue : Color.gray.opacity(0.2))
    }
}
