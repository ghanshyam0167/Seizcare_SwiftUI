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
    let sleepHours: Double?
    let seizureCount: Int
}

// MARK: - Data Aggregation

private func alignedData(
    records: [SeizureRecord],
    sleep: [SleepData],
    range: TimeFrameRange
) -> [TimePoint] {
    let cal = Calendar.current
    let now = Date()

    switch range {
    case .daily:
        return []

    case .weekly:
        return (0..<7).reversed().compactMap { offset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let dayStart = cal.startOfDay(for: start)
            guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            
            let count = records.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }.count
            let hours = sleep.first { cal.isDate($0.date, inSameDayAs: dayStart) }?.duration
            return TimePoint(date: dayStart, sleepHours: hours, seizureCount: count)
        }

    case .monthly:
        return (0..<30).reversed().compactMap { offset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let dayStart = cal.startOfDay(for: start)
            guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            
            let count = records.filter { $0.startTime >= dayStart && $0.startTime < dayEnd }.count
            let hours = sleep.first { cal.isDate($0.date, inSameDayAs: dayStart) }?.duration
            return TimePoint(date: dayStart, sleepHours: hours, seizureCount: count)
        }

    case .yearly:
        return (0..<12).reversed().compactMap { offset -> TimePoint? in
            guard let start = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let comps = cal.dateComponents([.year, .month], from: start)
            guard let monthStart = cal.date(from: comps),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
            
            let count = records.filter { $0.startTime >= monthStart && $0.startTime < monthEnd }.count
            let monthSleeps = sleep.filter { $0.date >= monthStart && $0.date < monthEnd }
            let avgHours: Double? = monthSleeps.isEmpty ? nil
                : monthSleeps.reduce(0) { $0 + $1.duration } / Double(monthSleeps.count)
            return TimePoint(date: monthStart, sleepHours: avgHours, seizureCount: count)
        }
    }
}

// MARK: - Full Screen Chart View

struct SleepVsSeizuresChartView: View {
    let records: [SeizureRecord]
    let sleep: [SleepData]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TimeFrameRange = .weekly
    @State private var selectedDate: Date?

    private var data: [TimePoint] {
        alignedData(records: records, sleep: sleep, range: selectedRange)
    }

    private var avgSleep: Double {
        let vals = data.compactMap { $0.sleepHours }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }

    private var totalSeizures: Int { data.reduce(0) { $0 + $1.seizureCount } }

    private var maxSeizures: Double {
        Double(max(1, data.map { $0.seizureCount }.max() ?? 1))
    }

    // Y-Axis is strictly Seizures. 
    // By dividing maxSeizures by 0.35, the tallest bar will always visually stop at exactly 35% of the chart height.
    private var chartMaxY: Double {
        max(5.0, maxSeizures / 0.35)
    }

    private func normalizedSleep(_ sleepHours: Double) -> Double {
        // Sleep is evaluated on a 0-10 scale.
        // We map it to the Y-axis so it stays perfectly stable visually, regardless of seizure counts.
        let clampedSleep = min(10.0, max(0.0, sleepHours))
        return (clampedSleep / 10.0) * chartMaxY
    }

    private var selectedPoint: TimePoint? {
        guard let sel = selectedDate else { return nil }
        let closest = data.min(by: {
            abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel))
        })
        if closest?.seizureCount == 0 { return nil }
        return closest
    }

    private var insightText: String {
        let poorDays = data.filter { ($0.sleepHours ?? 99) < 6 && $0.seizureCount > 0 }.count
        let unit = selectedRange == .yearly ? "months" : "days"
        return "\(poorDays) \(unit) with poor sleep (<6h) coincided with a seizure."
    }

    private var avgSleepLabel: String {
        selectedRange == .yearly ? "Avg Monthly Sleep" : "Avg Sleep"
    }

    private func barColor(for pt: TimePoint) -> Color {
        let base = Color(red: 1.0, green: 0.38, blue: 0.38)
        return (selectedPoint == nil || selectedPoint?.id == pt.id) ? base.opacity(0.8) : base.opacity(0.3)
    }

    private func outerCircleSize(for pt: TimePoint) -> CGFloat {
        return selectedPoint?.id == pt.id ? 80 : 55
    }

    private func innerCircleSize(for pt: TimePoint) -> CGFloat {
        return selectedPoint?.id == pt.id ? 30 : 18
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                
                Spacer()
                
                Text("Sleep vs Seizures")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Spacer()
                
                Circle()
                    .fill(Color.clear)
                    .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background(Color(UIColor.systemGroupedBackground))
            
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Segmented range picker
                        Picker("Range", selection: $selectedRange) {
                            Text("Last 7 Days").tag(TimeFrameRange.weekly)
                            Text("Last 30 Days").tag(TimeFrameRange.monthly)
                            Text("Last 12 Months").tag(TimeFrameRange.yearly)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .onChange(of: selectedRange) { _, _ in selectedDate = nil }

                        // Stat cards
                        HStack(spacing: 12) {
                            statCard(label: avgSleepLabel,
                                     value: String(format: "%.1fh", avgSleep),
                                     color: Color(red: 0.27, green: 0.57, blue: 1.0))
                            statCard(label: "Total Seizures",
                                     value: "\(totalSeizures)",
                                     color: Color(red: 1.0, green: 0.38, blue: 0.38))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                        // Legend row
                        HStack(spacing: 16) {
                            legendDot(color: Color(red: 0.27, green: 0.57, blue: 1.0),
                                      label: "Sleep (trend)")
                            legendDot(color: Color(red: 1.0, green: 0.38, blue: 0.38),
                                      label: "Seizures (count)")
                            Spacer()
                            if let pt = selectedPoint {
                                Text(tooltipDateLabel(pt.date))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(UIColor.label))
                            } else {
                                Text(tooltipDateLabel(Date()))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.clear)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                        // Chart — directly on gray, no card wrapper
                        Chart {
                            ForEach(data) { pt in
                                BarMark(
                                    x: .value("Date", pt.date),
                                    y: .value("Seizures", pt.seizureCount),
                                    width: .fixed(12)
                                )
                                .foregroundStyle(barColor(for: pt))
                                .cornerRadius(4)
                            }

                            // Sleep circles — only on days that ALSO have a seizure event
                            ForEach(data.filter { $0.seizureCount > 0 }) { pt in
                                if let h = pt.sleepHours {
                                    LineMark(
                                        x: .value("Date", pt.date),
                                        y: .value("SleepTrend", normalizedSleep(h))
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
                                    .lineStyle(StrokeStyle(lineWidth: 3))

                                    // Open circle outer (background fill)
                                    PointMark(
                                        x: .value("Date", pt.date),
                                        y: .value("SleepTrend", normalizedSleep(h))
                                    )
                                    .foregroundStyle(Color(UIColor.systemGroupedBackground))
                                    .symbolSize(outerCircleSize(for: pt))

                                    // Open circle inner (blue ring)
                                    PointMark(
                                        x: .value("Date", pt.date),
                                        y: .value("SleepTrend", normalizedSleep(h))
                                    )
                                    .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
                                    .symbolSize(innerCircleSize(for: pt))
                                }
                            }
                            

                            if let pt = selectedPoint {
                                RuleMark(x: .value("Selected", pt.date))
                                    .foregroundStyle(Color(UIColor.secondaryLabel).opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                        }
                        .chartYScale(domain: 0...chartMaxY)
                        .chartYAxis {
                            AxisMarks(position: .leading) { v in
                                AxisGridLine()
                                    .foregroundStyle(Color(UIColor.separator).opacity(0.4))
                                AxisValueLabel {
                                    if let val = v.as(Int.self) {
                                        Text("\(val)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(UIColor.secondaryLabel))
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { v in
                                AxisValueLabel {
                                    if let d = v.as(Date.self) {
                                        Text(xAxisLabel(d))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(UIColor.secondaryLabel))
                                            .opacity(selectedPoint == nil ? 1 : 0)
                                    }
                                }
                            }
                        }
                        .chartXSelection(value: $selectedDate)
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                if let pt = selectedPoint,
                                   let plotFrame = proxy.plotFrame,
                                   let xPos = proxy.position(forX: pt.date) {
                                    
                                    // Keep bubble within screen bounds
                                    let safeX = min(max(xPos + geo[plotFrame].origin.x, 60), geo.size.width - 60)
                                    
                                    tooltipBubble(pt)
                                        .position(x: safeX, y: geo[plotFrame].origin.y - 12)
                                }
                            }
                        }
                        .frame(height: 320)
                        .emptyChartOverlay(isEmpty: records.isEmpty)
                        .padding(.top, 24)
                        .padding(.horizontal, 16)

                        // Insight card
                        insightCard
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }

    // MARK: - Helpers

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.secondaryLabel))
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15))
                .foregroundStyle(.yellow)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Insight")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(UIColor.label))
                Text(insightText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func tooltipBubble(_ pt: TimePoint) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 0.27, green: 0.57, blue: 1.0))
                    .frame(width: 7, height: 7)
                Text(String(format: "%.1fh", pt.sleepHours ?? 0.0))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.38, blue: 0.38))
                    .frame(width: 7, height: 7)
                Text("\(pt.seizureCount) event\(pt.seizureCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color(UIColor.secondaryLabel))
        }
    }

    private func xAxisLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch selectedRange {
        case .weekly:  fmt.dateFormat = "EEE"
        case .monthly: fmt.dateFormat = "d"
        case .yearly:  fmt.dateFormat = "MMM"
        default:       fmt.dateFormat = "d"
        }
        return fmt.string(from: date)
    }

    private func tooltipDateLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch selectedRange {
        case .weekly:  fmt.dateFormat = "EEEE"
        case .monthly: fmt.dateFormat = "MMMM d"
        case .yearly:  fmt.dateFormat = "MMMM yyyy"
        default:       fmt.dateFormat = "MMMM d"
        }
        return fmt.string(from: date)
    }
}

// MARK: - Mini Chart (Dashboard Preview)

struct SleepVsSeizuresMiniChart: View {
    let records: [SeizureRecord]
    let sleep: [SleepData]

    private var weekData: [TimePoint] {
        alignedData(records: records, sleep: sleep, range: .weekly)
    }

    private var avgSleep: Double {
        let vals = weekData.compactMap { $0.sleepHours }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }

    private var totalSeizures: Int { weekData.reduce(0) { $0 + $1.seizureCount } }

    private var maxSeizures: Double {
        Double(max(1, weekData.map { $0.seizureCount }.max() ?? 1))
    }

    private var chartMaxY: Double {
        max(5.0, maxSeizures / 0.35)
    }

    private func normalizedSleep(_ sleepHours: Double) -> Double {
        let clampedSleep = min(10.0, max(0.0, sleepHours))
        return (clampedSleep / 10.0) * chartMaxY
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Period label
            Text("Last 7 Days")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.dashSecondary)

if records.isEmpty {
    VStack(spacing: 8) {
        Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.system(size: 20))
            .foregroundStyle(Color.dashSecondary.opacity(0.6))
        Text("No data available yet...")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.dashSecondary)
            .lineLimit(1)
        Text("Start tracking to see summary.")
            .font(.system(size: 11))
            .foregroundStyle(Color.dashSecondary.opacity(0.8))
            .lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(height: 110)
} else {

    // Stats row
    Text("\(String(format: "%.1f", avgSleep)) vs \(totalSeizures)")
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
        .padding(.bottom, 4)

    // Mini chart (CORRECT VERSION)
    Chart {
        ForEach(weekData) { pt in
            BarMark(
                x: .value("Day", pt.date),
                y: .value("Seizures", pt.seizureCount),
                width: .fixed(8)
            )
            .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38).opacity(0.85))
            .cornerRadius(4)
        }

        // Sleep trend (normalized — IMPORTANT)
        ForEach(weekData.filter { $0.seizureCount > 0 }) { pt in
            if let h = pt.sleepHours {
                LineMark(
                    x: .value("Day", pt.date),
                    y: .value("SleepTrend", normalizedSleep(h))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
                .lineStyle(StrokeStyle(lineWidth: 3))

                PointMark(
                    x: .value("Day", pt.date),
                    y: .value("SleepTrend", normalizedSleep(h))
                )
                .foregroundStyle(Color.dashCard)
                .symbolSize(36)

                PointMark(
                    x: .value("Day", pt.date),
                    y: .value("SleepTrend", normalizedSleep(h))
                )
                .foregroundStyle(Color(red: 0.27, green: 0.57, blue: 1.0))
                .symbolSize(14)
            }
        }
    }
    .chartYScale(domain: 0...chartMaxY)
    .chartXAxis {
        AxisMarks(values: .automatic) { value in
            AxisValueLabel(centered: false) {
                if let date = value.as(Date.self) {
                    Text(miniXLabel(date))
                        .font(.system(size: 8))
                        .foregroundStyle(Color.dashSecondary)
                }
            }
        }
    }
    .chartYAxis(.hidden)
    .frame(height: 88)
}
        }
    }

    private func miniXLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(3))
    }
}