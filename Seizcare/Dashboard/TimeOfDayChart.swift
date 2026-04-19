//
//  TimeOfDayChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Mini Preview

struct TimeOfDayMiniChart: View {
    let records: [SeizureRecord]
    private var data: [(label: String, count: Int, color: Color)] { records.timeOfDayCounts() }

    var body: some View {
        Chart(data, id: \.label) { item in
            BarMark(
                x: .value("Period", String(localized: String.LocalizationValue(item.label))),
                y: .value("Count", item.count)
            )
            .foregroundStyle(item.color.opacity(0.8))
            .cornerRadius(4)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Full Screen

struct TimeOfDayChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]

    private var data: [(label: String, count: Int, color: Color)] { records.timeOfDayCounts() }
    private var total: Int { records.count }
    private var peak: String { records.peakTimeKey }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Donut chart
                    ZStack {
                        Chart(data, id: \.label) { item in
                            SectorMark(
                                angle:       .value("Count",   item.count == 0 ? 0.001 : Double(item.count)),
                                innerRadius: .ratio(0.55),
                                angularInset: 3
                            )
                            .foregroundStyle(item.color.opacity(item.count == 0 ? 0.15 : 0.85))
                            .cornerRadius(6)
                        }
                        .frame(width: 220, height: 220)

                        // Center label
                        VStack(spacing: 4) {
                            Text("peak")
                                .font(.caption)
                                .foregroundStyle(Color.dashSecondary)
                            Text(LocalizedStringKey(peak))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.dashLabel)
                            Text("\(total) total")
                                .font(.caption2)
                                .foregroundStyle(Color.dashTertiary)
                        }
                    }
                    .padding(24)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Breakdown rows
                    VStack(spacing: 10) {
                        ForEach(data, id: \.label) { item in
                            TimeSlotRow(item: item, total: total)
                        }
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Insight
                    if !peak.isEmpty && peak != "—" {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.dashSleep)
                            Text("time_of_day_insight \(String(localized: String.LocalizationValue(peak)))")
                                .font(.caption)
                                .foregroundStyle(Color.dashSecondary)
                        }
                        .padding(16)
                        .background(Color.dashCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("time_of_day")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { dismiss() }
                        .foregroundStyle(Color.dashSeizure)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TimeSlotRow: View {
    let item: (label: String, count: Int, color: Color)
    let total: Int

    private var pct: Double {
        total == 0 ? 0 : Double(item.count) / Double(total)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.color)
                .frame(width: 10, height: 10)
            Text(LocalizedStringKey(item.label))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.dashLabel)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(item.color.opacity(0.15)).frame(height: 8)
                    Capsule().fill(item.color).frame(width: geo.size.width * pct, height: 8)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dashSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
