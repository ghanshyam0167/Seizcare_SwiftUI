//
//  ReportView.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Report Duration

enum ReportDuration: String, CaseIterable, Identifiable {
    case month1 = "Last 1 Month"
    case month3 = "Last 3 Months"
    case month6 = "Last 6 Months"
    var id: String { rawValue }

    var days: Int {
        switch self {
        case .month1: return 30
        case .month3: return 90
        case .month6: return 180
        }
    }
}

// MARK: - Report Options Sheet

struct ReportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (ReportDuration) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ForEach(ReportDuration.allCases) { duration in
                    Button {
                        dismiss()
                        onSelect(duration)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.dashSleep)
                                .frame(width: 32)
                            Text(duration.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.dashLabel)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dashTertiary)
                        }
                        .padding(16)
                        .background(Color.dashCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                Spacer()
            }
            .padding(20)
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.dashSecondary)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

// MARK: - Report View

struct ReportView: View {
    let records: [SeizureRecord]
    let duration: ReportDuration
    @Environment(\.dismiss) private var dismiss

    // MARK: - Analytics

    private var totalCount: Int { records.count }
    private var autoCount: Int { records.filter { $0.entryType == .automatic }.count }
    private var manualCount: Int { records.filter { $0.entryType == .manual }.count }

    private var avgDurationText: String {
        guard !records.isEmpty else { return "—" }
        let avg = records.averageDurationSeconds
        let m = Int(avg / 60)
        let s = Int(avg.truncatingRemainder(dividingBy: 60))
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var longestDurationText: String {
        guard let longest = records.max(by: { $0.duration < $1.duration }) else { return "—" }
        let m = Int(longest.duration / 60)
        let s = Int(longest.duration.truncatingRemainder(dividingBy: 60))
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var avgSleepText: String {
        let calendar = Calendar.current
        let now = Date()
        let months = max(duration.days / 30, 1)
        var monthlyAvgs: [Double] = []

        for offset in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: now),
                  let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let end   = calendar.date(byAdding: .month, value: 1, to: start) else { continue }

            let nights = MockDashboardData.sleepRecords.filter { $0.date >= start && $0.date < end }
            guard !nights.isEmpty else { continue }
            let avg = nights.reduce(0.0) { $0 + $1.hours } / Double(nights.count)
            monthlyAvgs.append(avg)
        }

        guard !monthlyAvgs.isEmpty else { return "—" }
        let overall = monthlyAvgs.reduce(0, +) / Double(monthlyAvgs.count)
        let h = Int(overall)
        let m = Int((overall - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private var mostCommonTrigger: String {
        records.triggerFrequency().first?.trigger.rawValue ?? "—"
    }

    private var severityData: [(label: String, count: Int, color: Color)] {
        SeizureType.allCases.map { type in
            let count = records.filter { $0.type == type }.count
            return (type.displayName, count, type.color)
        }.filter { $0.count > 0 }
    }

    private var triggerData: [(trigger: SeizureTrigger, percentage: Double)] {
        Array(records.triggerFrequency().prefix(5))
    }

    private var timeOfDayData: [(label: String, count: Int, color: Color)] {
        records.timeOfDayCounts().filter { $0.count > 0 }
    }

    private var monthlyData: [(label: String, count: Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        let months = max(duration.days / 30, 3)  // always show at least 3 months
        return records.monthlyCounts(over: months).map { (fmt.string(from: $0.date), $0.count) }
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -duration.days, to: end) ?? end
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    reportHeader
                    summaryStatsCard
                    entryTypeCard
                    if !severityData.isEmpty { severityChartCard }
                    if !triggerData.isEmpty  { triggerBreakdownCard }
                    if !timeOfDayData.isEmpty { timeOfDayCard }
                    monthlyTrendCard

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.dashSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: reportSummaryText,
                        subject: Text("Seizure Report"),
                        message: Text("Seizure report for \(duration.rawValue.lowercased())")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.dashSleep)
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var reportHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.dashSleep.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.dashSleep)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(duration.rawValue)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
                Text(dateRangeText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dashSecondary)
                Text("Generated \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashTertiary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            reportSectionHeader(title: "Summary", icon: "chart.bar.fill", color: .dashSeizure)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(icon: "waveform.path.ecg",        label: "Total Events",   value: "\(totalCount)",         color: .dashSeizure)
                StatCard(icon: "timer",                    label: "Avg Duration",   value: avgDurationText,         color: .dashSleep)
                StatCard(icon: "bolt.fill",                label: "Top Trigger",    value: mostCommonTrigger,       color: Color(red: 1.0, green: 0.6, blue: 0.2))
                StatCard(icon: "clock.badge.checkmark",    label: "Peak Time",      value: records.peakTimeLabel,   color: Color(red: 0.8, green: 0.6, blue: 1.0))
                StatCard(icon: "stopwatch",                label: "Longest Event",  value: longestDurationText,     color: Color(red: 0.4, green: 0.8, blue: 0.6))
                StatCard(icon: "moon.zzz.fill",            label: "Monthly Sleep",  value: avgSleepText,            color: Color(red: 0.5, green: 0.7, blue: 1.0))
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var entryTypeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            reportSectionHeader(title: "Detection Source", icon: "waveform", color: Color(red: 0.5, green: 0.7, blue: 1.0))

            HStack(spacing: 12) {
                // Auto
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.dashSleep)
                        Text("Auto-Detected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dashSecondary)
                    }
                    Text("\(autoCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.dashSleep)
                    Text("events")
                        .font(.caption2)
                        .foregroundStyle(Color.dashTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.dashSleep.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Manual
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                        Text("Manual Entry")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dashSecondary)
                    }
                    Text("\(manualCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                    Text("events")
                        .font(.caption2)
                        .foregroundStyle(Color.dashTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var severityChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Severity Distribution", icon: "chart.pie.fill", color: Color(red: 0.8, green: 0.6, blue: 1.0))

            HStack(spacing: 20) {
                // Donut
                Chart(severityData, id: \.label) { item in
                    SectorMark(
                        angle: .value("Count", max(item.count, 0)),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(width: 130, height: 130)

                // Legend with counts
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(severityData, id: \.label) { item in
                        HStack(spacing: 10) {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            Text(item.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.dashLabel)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(item.color)
                            let pct = totalCount > 0 ? Int(Double(item.count) / Double(totalCount) * 100) : 0
                            Text("(\(pct)%)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dashTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var triggerBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Top Triggers", icon: "bolt.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2))

            VStack(spacing: 10) {
                ForEach(Array(triggerData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 5) {
                        HStack {
                            Text(item.trigger.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.dashLabel)
                            Spacer()
                            Text(String(format: "%.0f%%", item.percentage))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashSecondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.dashTertiary.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.38, blue: 0.38)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(item.percentage / 100), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var timeOfDayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Time of Day", icon: "clock.fill", color: Color.dashSleep)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(records.timeOfDayCounts(), id: \.label) { item in
                    VStack(spacing: 6) {
                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(item.count > 0 ? item.color : Color.dashTertiary)

                        let maxCount = records.timeOfDayCounts().map { $0.count }.max() ?? 1
                        let heightRatio = maxCount > 0 ? CGFloat(item.count) / CGFloat(maxCount) : 0
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.count > 0 ? item.color.opacity(0.8) : Color.dashTertiary.opacity(0.2))
                            .frame(height: max(8, 80 * heightRatio))

                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.dashSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var monthlyTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Monthly Trend", icon: "chart.line.uptrend.xyaxis", color: Color.dashSleep)

            if monthlyData.allSatisfy({ $0.count == 0 }) {
                emptyChartState
            } else {
                Chart(monthlyData, id: \.label) { point in
                    AreaMark(
                        x: .value("Month", point.label),
                        y: .value("Count", point.count)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.dashSleep.opacity(0.25), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    LineMark(
                        x: .value("Month", point.label),
                        y: .value("Count", point.count)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(Color.dashSleep)
                    PointMark(
                        x: .value("Month", point.label),
                        y: .value("Count", point.count)
                    )
                    .foregroundStyle(Color.dashSleep)
                    .symbolSize(36)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label).font(.caption2).foregroundStyle(Color.dashTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.2))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)").font(.caption2).foregroundStyle(Color.dashTertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyChartState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.dashTertiary)
                Text("No data in this period")
                    .font(.caption)
                    .foregroundStyle(Color.dashSecondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    @ViewBuilder
    private func reportSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.dashLabel)
        }
    }

    private var reportSummaryText: String {
        let triggerLines = triggerData.map { "  \($0.trigger.rawValue): \(String(format: "%.0f", $0.percentage))%" }.joined(separator: "\n")
        let severityLines = severityData.map { "  \($0.label): \($0.count)" }.joined(separator: "\n")
        return """
        Seizcare Seizure Report — \(duration.rawValue)
        Period: \(dateRangeText)
        Generated: \(Date().formatted(date: .long, time: .omitted))

        ── Summary ──
        Total Events: \(totalCount)
        Auto-Detected: \(autoCount)
        Manual Entries: \(manualCount)
        Avg Duration: \(avgDurationText)
        Longest Event: \(longestDurationText)
        Top Trigger: \(mostCommonTrigger)
        Peak Time: \(records.peakTimeLabel)

        ── Severity Breakdown ──
        \(severityLines)

        ── Top Triggers ──
        \(triggerLines)
        """
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.dashSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.dashCardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
