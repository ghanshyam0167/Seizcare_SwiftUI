//
//  SleepVsSeizuresChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - TimePoint Data Model

private struct TimePoint: Identifiable {
    let id = UUID()
    let date: Date
    let sleepValue: Double? // Optional: prevents line from crashing to 0 when no data
    let seizureCount: Int  // Count (daily total or monthly total)
}

// MARK: - Data Aggregation

private func alignedData(records: [SeizureRecord], sleep: [SleepRecord], range: TimeFrameRange) -> [TimePoint] {
    let cal = Calendar.current
    let now = Date()
    
    switch range {
    case .daily:
        return []
        
    case .weekly:
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let startOfMonday = cal.date(from: comps) else { return [] }
        
        return (0..<7).compactMap { dayOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: dayOffset, to: startOfMonday),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            let sHours = sleep.first { cal.isDate($0.date, inSameDayAs: start) }?.hours
            return TimePoint(date: start, sleepValue: sHours, seizureCount: sCount)
        }
        
    case .monthly:
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let startOfMonth = cal.date(from: comps),
              let daysRange = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        
        return (0..<daysRange.count).compactMap { dayOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            let sHours = sleep.first { cal.isDate($0.date, inSameDayAs: start) }?.hours
            return TimePoint(date: start, sleepValue: sHours, seizureCount: sCount)
        }
        
    case .yearly:
        let year = cal.component(.year, from: now)
        guard let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        
        return (0..<12).compactMap { monthOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .month, value: monthOffset, to: startOfYear),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            let monthSleeps = sleep.filter { $0.date >= start && $0.date < end }
            let avgSleep: Double? = monthSleeps.isEmpty ? nil : monthSleeps.reduce(0.0) { $0 + $1.hours } / Double(monthSleeps.count)
            
            return TimePoint(date: start, sleepValue: avgSleep, seizureCount: sCount)
        }
    }
}

// MARK: - Formatting Helpers

private func xAxisLabel(for date: Date, range: TimeFrameRange) -> String {
    let f = DateFormatter()
    switch range {
    case .weekly:  f.dateFormat = "EEE" // Mon, Tue
    case .monthly: f.dateFormat = "d"   // 1, 2, 15
    case .yearly:  f.dateFormat = "MMM" // Jan, Feb
    default: return ""
    }
    return f.string(from: date)
}

private func tooltipDateLabel(for date: Date, range: TimeFrameRange) -> String {
    let f = DateFormatter()
    switch range {
    case .weekly, .monthly: f.dateFormat = "d MMM yyyy"
    case .yearly: f.dateFormat = "MMMM yyyy"
    default: return ""
    }
    return f.string(from: date)
}

// MARK: - Mini Preview

struct SleepVsSeizuresMiniChart: View {
    let records: [SeizureRecord]
    let sleep: [SleepRecord]

    private var data: [TimePoint] { alignedData(records: records, sleep: sleep, range: .weekly) }
    
    private var totalSeizures: Int { data.reduce(0) { $0 + $1.seizureCount } }
    private var avgSleep: Double {
        let validDays = data.compactMap { $0.sleepValue }.filter { $0 > 0 }
        if validDays.isEmpty { return 0 }
        return validDays.reduce(0.0, +) / Double(validDays.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("This Week")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.dashSecondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", avgSleep))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dashSleep)
                Text("HRS AVG")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.dashSleep)
                
                Text("\(totalSeizures)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dashSeizure)
                    .padding(.leading, 8)
                Text("EVENTS")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.dashSeizure)
            }
            .padding(.bottom, 4)
            
            let maxSleep = max(10.0, (data.compactMap { $0.sleepValue }.max() ?? 8.0) + 2.0)
            let maxSeizures = max(1, data.map { $0.seizureCount }.max() ?? 1)
            // Decouple seizure bars: keep them in the bottom 35% of the chart
            let seizureScaleFactor = (maxSleep * 0.35) / Double(maxSeizures)
            
            Chart(data) { pt in
                // SLEEP LINE
                if let sleepVal = pt.sleepValue {
                    LineMark(
                        x: .value("Time", pt.date, unit: .day),
                        y: .value("Sleep", sleepVal)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Color.dashSleep)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    if pt.seizureCount > 0 {
                        PointMark(
                            x: .value("Time", pt.date, unit: .day),
                            y: .value("Sleep", sleepVal)
                        )
                        .symbol {
                            Circle()
                                .fill(Color.dashBg)
                                .overlay(Circle().stroke(Color.dashSleep, lineWidth: 1.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                // SEIZURE BARS
                if pt.seizureCount > 0 {
                    BarMark(
                        x: .value("Time", pt.date, unit: .day),
                        y: .value("Seizures", Double(pt.seizureCount) * seizureScaleFactor)
                    )
                    .foregroundStyle(Color.dashSeizure.opacity(0.8))
                }
            }
            .chartYScale(domain: 0...maxSleep)
            .chartXScale(range: .plotDimension(padding: 15))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: 1)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date, range: .weekly))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.dashSecondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 70)
        }
    }
}

// MARK: - Full Screen

struct SleepVsSeizuresChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]
    let sleep: [SleepRecord]

    @State private var selectedRange: TimeFrameRange = .weekly

    private let availableRanges: [TimeFrameRange] = [.weekly, .monthly, .yearly]

    @State private var selectedDate: Date?

    private var data: [TimePoint] { alignedData(records: records, sleep: sleep, range: selectedRange) }

    private var selectedPoint: TimePoint? {
        guard let selectedDate else { return nil }
        let cal = Calendar.current
        return data.first(where: {
            let start = $0.date
            let end: Date
            switch selectedRange {
            case .weekly, .monthly: end = cal.date(byAdding: .day, value: 1, to: start)!
            case .yearly: end = cal.date(byAdding: .month, value: 1, to: start)!
            default: end = cal.date(byAdding: .day, value: 1, to: start)!
            }
            return selectedDate >= start && selectedDate < end && $0.seizureCount > 0
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Range Picker
                        Picker("Range", selection: $selectedRange) {
                            Text("This Week").tag(TimeFrameRange.weekly)
                            Text("This Month").tag(TimeFrameRange.monthly)
                            Text("This Year").tag(TimeFrameRange.yearly)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // Summary Stats
                        let validSleep = data.compactMap { $0.sleepValue }.filter { $0 > 0 }
                        let overallAvgSleep = validSleep.isEmpty ? 0.0 : validSleep.reduce(0.0, +) / Double(validSleep.count)
                        let overallTotalSeizures = data.reduce(0) { $0 + $1.seizureCount }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedRange == .yearly ? "Avg Monthly Sleep" : "Avg Sleep")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.dashSecondary)
                                Text(String(format: "%.1fh", overallAvgSleep))
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.dashSleep)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.dashCard)
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Seizures")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.dashSecondary)
                                Text("\(overallTotalSeizures)")
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.dashSeizure)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.dashCard)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        // Legend
                        HStack(spacing: 20) {
                            LegendDot(color: .dashSleep,   label: selectedRange == .yearly ? "Avg Sleep (hrs)" : "Sleep (hrs)")
                            LegendDot(color: .dashSeizure, label: selectedRange == .yearly ? "Total Seizures" : "Seizures")
                        }
                        .padding(.horizontal, 16)
                        
                        let unit: Calendar.Component = selectedRange == .yearly ? .month : .day
                        let maxSleep = max(10.0, (data.compactMap { $0.sleepValue }.max() ?? 8.0) + 2.0)
                        let maxSeizures = max(1, data.map { $0.seizureCount }.max() ?? 1)
                        // Decouple seizure bars: keep them in the bottom 35% of the chart
                        let seizureScaleFactor = (maxSleep * 0.35) / Double(maxSeizures)
                        
                        // Main Interactive Chart
                        Chart(data) { pt in
                            // SLEEP LINE
                            if let sleepVal = pt.sleepValue {
                                LineMark(
                                    x: .value("Time", pt.date, unit: unit),
                                    y: .value("Sleep", sleepVal),
                                    series: .value("Series", "Sleep")
                                )
                                .interpolationMethod(.linear)
                                .foregroundStyle(Color.dashSleep)
                                .lineStyle(StrokeStyle(lineWidth: 3))

                                // SLEEP POINTS (only on seizure days/months)
                                if pt.seizureCount > 0 {
                                    PointMark(
                                        x: .value("Time", pt.date, unit: unit),
                                        y: .value("Sleep", sleepVal)
                                    )
                                    .symbol {
                                        Circle()
                                            .fill(Color.dashBg)
                                            .overlay(Circle().stroke(Color.dashSleep, lineWidth: 3))
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }

                            // SEIZURE BARS
                            if pt.seizureCount > 0 {
                                BarMark(
                                    x: .value("Time", pt.date, unit: unit),
                                    y: .value("Seizures", Double(pt.seizureCount) * seizureScaleFactor)
                                )
                                .foregroundStyle(Color.dashSeizure.opacity(0.8))
                            } else if pt.sleepValue == nil {
                                // Invisible mark to preserve X-axis domain when no data exists
                                BarMark(
                                    x: .value("Time", pt.date, unit: unit),
                                    y: .value("Seizures", 0)
                                )
                                .foregroundStyle(Color.clear)
                            }
                            
                            // TOOLTIP ANNOTATION
                            if let selectedPoint, selectedPoint.date == pt.date {
                                RuleMark(x: .value("Time", pt.date, unit: unit))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(tooltipDateLabel(for: pt.date, range: selectedRange))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.dashLabel)
                                            
                                            HStack(spacing: 12) {
                                                if let sleepVal = pt.sleepValue {
                                                    HStack(spacing: 4) {
                                                        Circle().fill(Color.dashSleep).frame(width: 8, height: 8)
                                                        Text("\(String(format: "%.1f", sleepVal))h")
                                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                            .foregroundStyle(Color.dashLabel)
                                                    }
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Circle().fill(Color.dashSleep).frame(width: 8, height: 8)
                                                        Text("No Data")
                                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                            .foregroundStyle(Color.dashSecondary)
                                                    }
                                                }
                                                HStack(spacing: 4) {
                                                    Circle().fill(Color.dashSeizure).frame(width: 8, height: 8)
                                                    Text("\(pt.seizureCount)")
                                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                        .foregroundStyle(Color.dashLabel)
                                                }
                                            }
                                        }
                                        .padding(12)
                                        .background(Color.dashCardElevated)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                                    }
                            }
                        }
                        .chartYScale(domain: 0...maxSleep)
                        .chartXSelection(value: $selectedDate)
                        .chartXAxis {
                            let strideCount = selectedRange == .monthly ? 5 : 1
                            AxisMarks(values: .stride(by: unit, count: strideCount)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(xAxisLabel(for: date, range: selectedRange))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dashSecondary)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                                    .foregroundStyle(Color.gray.opacity(0.2))
                                AxisValueLabel()
                                    .foregroundStyle(Color.dashSecondary)
                            }
                        }
                        .frame(height: 300)
                        .padding(.horizontal, 20)
                        
                        // Insight Card
                        CorrelationInsightCard(data: data, range: selectedRange)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Sleep vs Seizures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.dashLabel)
                            .padding(8)
                            .background(Circle().fill(Color.dashCard))
                    }
                }
            }
        }
    }
}

private struct CorrelationInsightCard: View {
    let data: [TimePoint]
    let range: TimeFrameRange

    private var poorSleepSeizureDays: Int {
        data.filter { ($0.sleepValue ?? 0) > 0 && ($0.sleepValue ?? 0) < 6 && $0.seizureCount > 0 }.count
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
                let unit = range == .yearly ? "months" : "days"
                Text("\(poorSleepSeizureDays) \(unit) with poor sleep (<6h) coincided with a seizure.")
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

