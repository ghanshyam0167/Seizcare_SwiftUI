//
//  SleepVsSeizuresChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Aligned daily data

private struct DayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let sleepHours: Double
    let seizureCount: Int
}

private func alignedData(records: [SeizureRecord], sleep: [SleepData], days: Int) -> [DayPoint] {
    let cal = Calendar.current
    let now = Date()
    return (0..<days).reversed().compactMap { offset -> DayPoint? in
        guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
        let start  = cal.startOfDay(for: day)
        let sCount = records.filter { cal.isDate($0.startTime, inSameDayAs: start) }.count
        let sHours = sleep.first { cal.isDate($0.date, inSameDayAs: start) }?.duration ?? 0
        return DayPoint(date: start, sleepHours: sHours, seizureCount: sCount)
    }
}

// MARK: - Mini Preview

struct SleepVsSeizuresMiniChart: View {
    let records: [SeizureRecord]
    let sleep: [SleepData]

    private var data: [DayPoint] { alignedData(records: records, sleep: sleep, days: 14) }
    
    private var avgSleep: Double {
        let valid = data.filter { $0.sleepHours > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0) { $0 + $1.sleepHours } / Double(valid.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(avgSleep > 0 ? String(format: "Avg Sleep: %.1fh", avgSleep) : "No sleep data")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashSleep)
                
            Chart(data) { pt in
                LineMark(
                    x: .value("Day",   pt.date),
                    y: .value("Sleep", pt.sleepHours)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.dashSleep.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2))

                LineMark(
                    x: .value("Day",     pt.date),
                    y: .value("Seizure", Double(pt.seizureCount)) // Scaled implicitly
                )
                .interpolationMethod(.stepStart)
                .foregroundStyle(Color.dashSeizure.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }
}

// MARK: - Full Screen

struct SleepVsSeizuresChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]
    let sleep: [SleepData]

    private var data: [DayPoint] { alignedData(records: records, sleep: sleep, days: 21) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Legend
                    HStack(spacing: 20) {
                        LegendDot(color: .dashSleep,   label: "Sleep (hrs)")
                        LegendDot(color: .dashSeizure, label: "Seizures")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Dual-axis chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 21 Days")
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)

                        Chart(data) { pt in
                            LineMark(
                                x: .value("Day",   pt.date),
                                y: .value("Sleep", pt.sleepHours),
                                series: .value("Series", "Sleep")
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.dashSleep)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            AreaMark(
                                x: .value("Day",   pt.date),
                                y: .value("Sleep", pt.sleepHours),
                                series: .value("Series", "Sleep")
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.dashSleep.opacity(0.2), Color.clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Day",     pt.date),
                                y: .value("Seizure", Double(pt.seizureCount) * 2),
                                series: .value("Series", "Seizures")
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.dashSeizure)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                    .foregroundStyle(Color.dashSecondary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.3))
                                AxisValueLabel().foregroundStyle(Color.dashSecondary)
                            }
                        }
                        .frame(height: 260)
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Correlation insight
                    CorrelationInsightCard(data: data)
                }
                .padding(16)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("Sleep vs Seizures")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.dashSeizure)
                }
            }
        }
    }
}

private struct CorrelationInsightCard: View {
    let data: [DayPoint]

    private var poorSleepSeizureDays: Int {
        data.filter { $0.sleepHours > 0 && $0.sleepHours < 6 && $0.seizureCount > 0 }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.0))
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text("Insight")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
                Text("\(poorSleepSeizureDays) days with poor sleep (<6h) coincided with a seizure.")
                    .font(.caption)
                    .foregroundStyle(Color.dashSecondary)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(Color.dashSecondary)
        }
    }
}
