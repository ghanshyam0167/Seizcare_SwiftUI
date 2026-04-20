//
//  HeartRateTimelineChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Mini Preview

struct HeartRateMiniChart: View {
    let record: SeizureRecord

    private var samples: [HeartRateSample] {
        Array(MockDashboardData.heartRateSamples(for: record).prefix(30))
    }

    var body: some View {
        Chart(samples) { sample in
            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("BPM",  sample.bpm)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.dashSeizure.opacity(0.8))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Full Screen

struct HeartRateTimelineChartView: View {
    @Environment(\.dismiss) private var dismiss
    let record: SeizureRecord
    @State private var samples: [HeartRateSample] = []
    @State private var isLoading = true

    private func fetchSamples() {
        let start = record.startTime.addingTimeInterval(-30)
        var end: Date
        if let endTime = record.endTime {
            end = endTime.addingTimeInterval(60)
        } else {
            end = Date()
        }
        if end > Date() {
            end = Date()
        }
        
        HealthKitManager.shared.fetchHeartRateSamples(from: start, to: end) { fetched in
            DispatchQueue.main.async {
                if fetched.isEmpty {
                    // Fallback to mock if no real data found for this window
                    self.samples = MockDashboardData.heartRateSamples(for: record)
                } else {
                    self.samples = fetched
                }
                self.isLoading = false
            }
        }
    }

    // Relative minutes from seizure start
    private func relativeMinutes(_ timestamp: Date) -> Double {
        timestamp.timeIntervalSince(record.startTime) / 60.0
    }

    private var minBPM: Int { samples.map(\.bpm).min() ?? 50 }
    private var maxBPM: Int { samples.map(\.bpm).max() ?? 180 }
    private var peakBPM: Int {
        let effectiveEnd = record.endTime ?? record.startTime.addingTimeInterval(300)
        return samples
            .filter { $0.timestamp >= record.startTime && $0.timestamp <= effectiveEnd }
            .map(\.bpm)
            .max() ?? 0
    }
    private var recoveryBPM: Int { samples.last?.bpm ?? 0 }
    private var durationText: String {
        if record.endTime == nil { return "Measuring..." }
        let m = Int((record.duration ?? 0) / 60)
        return m > 0 ? "\(m) min" : "<1 min"
    }

    private var chartGradient: LinearGradient {
        let durationMins = (record.duration ?? 0) / 60.0
        let totalMins = 0.5 + durationMins + 1.0
        let startRatio = 0.5 / totalMins
        let endRatio = (0.5 + durationMins) / totalMins
        
        return LinearGradient(
            stops: [
                .init(color: Color.dashSleep.opacity(0.85), location: 0),
                .init(color: Color.dashSleep.opacity(0.85), location: startRatio - 0.01),
                .init(color: Color.dashSeizure, location: startRatio),
                .init(color: Color.dashSeizure, location: endRatio),
                .init(color: Color.dashGreen.opacity(0.85), location: endRatio + 0.01),
                .init(color: Color.dashGreen.opacity(0.85), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary stats
                    HStack(spacing: 0) {
                        HRStatTile(label: "baseline",  value: "\(minBPM)", unit: "bpm", color: .dashSleep)
                        HRStatTile(label: "peak",      value: "\(peakBPM)", unit: "bpm", color: .dashSeizure)
                        HRStatTile(label: "recovery",  value: "\(recoveryBPM)", unit: "bpm", color: .dashGreen)
                        HRStatTile(label: "duration",  value: durationText, unit: "", color: .dashSecondary)
                    }
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Phase labels
                    HStack(spacing: 0) {
                        PhasePill(label: "before",  color: .dashSleep)
                        Spacer()
                        PhasePill(label: "seizure", color: .dashSeizure)
                        Spacer()
                        PhasePill(label: "after",   color: .dashGreen)
                    }
                    .padding(.horizontal, 4)

                    // Heart rate chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("heart_rate_timeline")
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)

                        Chart {
                            // Seizure highlight region
                            let startVal = relativeMinutes(record.startTime)
                            let endVal = relativeMinutes(record.endTime ?? record.startTime.addingTimeInterval(300))
                            RectangleMark(
                                xStart: .value("Start", startVal),
                                xEnd:   .value("End",   endVal),
                                yStart: .value("Min", Double(minBPM - 10)),
                                yEnd:   .value("Max", Double(maxBPM + 10))
                            )
                            .foregroundStyle(Color.dashSeizure.opacity(0.08))

                            // HR line
                            ForEach(samples) { sample in
                                let mins = relativeMinutes(sample.timestamp)
                                LineMark(
                                    x: .value("Minutes", mins),
                                    y: .value("BPM",     sample.bpm)
                                )
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            }
                            .foregroundStyle(chartGradient)

                            // Seizure start marker
                            RuleMark(x: .value("Start", 0.0))
                                .foregroundStyle(Color.dashSeizure.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("onset")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.dashSeizure)
                                }

                            // Seizure end marker
                            RuleMark(x: .value("End", (record.duration ?? 0) / 60.0))
                                .foregroundStyle(Color.dashGreen.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .annotation(position: .bottom, alignment: .trailing) {
                                    Text("end")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.dashGreen)
                                }
                        }
                        .chartXScale(domain: -0.5 ... ((record.duration ?? 0) / 60.0 + 1.0))
                        .chartXAxis {
                            let durationMins = (record.duration ?? 0) / 60.0
                            AxisMarks(values: [-0.5, 0, durationMins, durationMins + 1.0]) { value in
                                AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.25))
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        if v == 0 { Text("Onset") }
                                        else if v == durationMins { Text("End") }
                                        else { Text(String(format: "%.1fm", v)) }
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.dashTertiary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [60, 80, 100, 120, 140, 160]) { value in
                                AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.25))
                                AxisValueLabel {
                                    if let v = value.as(Int.self) {
                                        Text("\(v)")
                                            .font(.caption2)
                                            .foregroundStyle(Color.dashTertiary)
                                    }
                                }
                            }
                        }
                        .frame(height: 280)
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Explanation card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("what_this_shows", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.dashLabel)
                        Text("hr_timeline_desc")
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
            .onAppear {
                fetchSamples()
            }
            .navigationTitle("heart_rate")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundStyle(Color.dashSeizure)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }
}

private struct HRStatTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(Color.dashSecondary)
                }
            }
            Text(LocalizedStringKey(label))
                .font(.caption2)
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

private struct PhasePill: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 4)
            Text(LocalizedStringKey(label))
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
    }
}
