//
//  ActivityRingsView.swift
//  Seizcare
//

import SwiftUI

struct ActivityRingsView: View {
    let sleepHours: Double
    let sleepGoal: Double
    let seizureControlPercent: Double  // 0–1

    private var sleepProgress:   Double { min(sleepHours / sleepGoal, 1.0) }
    private var controlProgress: Double { min(max(seizureControlPercent, 0), 1.0) }

    var body: some View {
        HStack(spacing: 24) {
            // Rings
            ZStack {
                // Outer ring: Seizure control (green)
                RingView(progress: controlProgress, color: .dashGreen, thickness: 12, size: 110)
                // Inner ring: Sleep (blue)
                RingView(progress: sleepProgress,   color: .dashSleep,  thickness: 12, size: 80)
            }

            // Legend
            VStack(alignment: .leading, spacing: 16) {
                RingLegendRow(
                    color: .dashSleep,
                    label: "Sleep Goal",
                    value: String(format: "%.1fh / %.0fh", sleepHours, sleepGoal),
                    percent: sleepProgress
                )
                RingLegendRow(
                    color: .dashGreen,
                    label: "Seizure Control",
                    value: String(format: "%.0f%%", controlProgress * 100),
                    percent: controlProgress
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Ring Shape

private struct RingView: View {
    let progress: Double
    let color: Color
    let thickness: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: thickness)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Legend Row

private struct RingLegendRow: View {
    let color: Color
    let label: String
    let value: String
    let percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.dashSecondary)
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * percent, height: 4)
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: percent)
                }
            }
            .frame(height: 4)
        }
    }
}
