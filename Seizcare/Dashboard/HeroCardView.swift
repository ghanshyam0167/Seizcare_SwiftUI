//
//  HeroCardView.swift
//  Seizcare
//

import SwiftUI
import Charts

struct HeroCardView: View {
    let records: [SeizureRecord]
    let sleepHours: Double
    let heartRate: Double
    var onSendAlert: () -> Void = {}

    private var thisMonth: [SeizureRecord] {
        let cal = Calendar.current
        return records.filter { cal.isDate($0.startTime, equalTo: Date(), toGranularity: .month) }
    }

    private var lastMonth: [SeizureRecord] {
        let cal = Calendar.current
        guard let last = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return records.filter { cal.isDate($0.startTime, equalTo: last, toGranularity: .month) }
    }

    private var isImproving: Bool { thisMonth.count <= lastMonth.count }

    private var avgSleep: Double { sleepHours }

    private var avgDuration: String {
        let secs = thisMonth.averageDurationSeconds
        if secs == 0 { return "—" }
        let mins = Int(secs / 60)
        return mins > 0 ? "\(mins)m" : "<1m"
    }

    private var sparklineData: [(date: Date, count: Int)] {
        records.dailyCounts(over: 14)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(Color.dashSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(thisMonth.count)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dashLabel)
                        Text("seizures")
                            .font(.subheadline)
                            .foregroundStyle(Color.dashSecondary)
                            .offset(y: -4)
                    }
                }

                Spacer()

                // Send alert button
                Button(action: onSendAlert) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Alert")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.dashSeizure.opacity(0.85))
                    .clipShape(Capsule())
                }
            }

            Spacer().frame(height: 20)

            // Sparkline
            Chart(sparklineData, id: \.date) { point in
                AreaMark(
                    x: .value("Day", point.date),
                    y: .value("Count", point.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.dashSeizure.opacity(0.25), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Day", point.date),
                    y: .value("Count", point.count)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.dashSeizure.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 52)

            Spacer().frame(height: 20)

            // Stats row
            HStack(spacing: 0) {
                StatPill(
                    icon: "moon.zzz.fill",
                    label: "Avg Sleep",
                    value: String(format: "%.1fh", avgSleep),
                    color: .dashSleep
                )
                Divider()
                    .frame(height: 32)
                    .background(Color.dashTertiary)
                    .padding(.horizontal, 12)
                StatPill(
                    icon: "timer",
                    label: "Avg Duration",
                    value: avgDuration,
                    color: .dashSecondary
                )
                Divider()
                    .frame(height: 32)
                    .background(Color.dashTertiary)
                    .padding(.horizontal, 12)
                StatPill(
                    icon: isImproving ? "arrow.down.right" : "arrow.up.right",
                    label: "Trend",
                    value: isImproving ? "Better" : "Worse",
                    color: isImproving ? .dashGreen : .dashSeizure
                )
                Divider()
                    .frame(height: 32)
                    .background(Color.dashTertiary)
                    .padding(.horizontal, 12)
                StatPill(
                    icon: "heart.fill",
                    label: "Current HR",
                    value: heartRate > 0 ? "\(Int(heartRate))" : "—",
                    color: .dashSeizure
                )
            }
        }
        .padding(20)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.dashSeizure.opacity(0.06), radius: 16, y: 6)
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
