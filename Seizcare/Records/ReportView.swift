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

    // MARK: Analytics computed

    private var totalCount: Int { records.count }

    private var avgDurationText: String {
        guard !records.isEmpty else { return "—" }
        let avg = records.averageDurationSeconds
        let m = Int(avg / 60)
        let s = Int(avg.truncatingRemainder(dividingBy: 60))
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var mostCommonTrigger: String {
        records.triggerFrequency().first?.trigger.rawValue ?? "—"
    }

    private var severityData: [(label: String, count: Int, color: Color)] {
        SeizureType.allCases.map { type in
            let count = records.filter { $0.type == type }.count
            return (type.displayName, count, type.color)
        }
    }

    private var monthlyData: [(label: String, count: Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        let months = duration.days / 30
        return records.monthlyCounts(over: max(months, 1)).map { (fmt.string(from: $0.date), $0.count) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header card
                    reportHeader

                    // Summary stats
                    summaryStatsCard

                    // Severity distribution
                    severityChartCard

                    // Monthly trend
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
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dashSleep)
                    }
                }
            }
        }
    }

    // MARK: Sub-views

    private var reportHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.dashSleep.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.dashSleep)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(duration.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
                Text("Generated \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.dashSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            reportSectionHeader(title: "Summary", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(icon: "waveform.path.ecg", label: "Total Events", value: "\(totalCount)", color: .dashSeizure)
                StatCard(icon: "timer", label: "Avg Duration", value: avgDurationText, color: .dashSleep)
                StatCard(icon: "bolt.fill", label: "Top Trigger", value: mostCommonTrigger, color: Color(red: 1.0, green: 0.6, blue: 0.2))
                StatCard(icon: "clock.badge.checkmark", label: "Peak Time", value: records.peakTimeLabel, color: Color(red: 0.8, green: 0.6, blue: 1.0))
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var severityChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Severity Distribution", icon: "chart.pie.fill")

            if severityData.allSatisfy({ $0.count == 0 }) {
                emptyChartState
            } else {
                Chart(severityData, id: \.label) { item in
                    SectorMark(
                        angle: .value("Count", max(item.count, 0)),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .center, spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach(severityData, id: \.label) { item in
                            HStack(spacing: 5) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text("\(item.label) (\(item.count))")
                                    .font(.caption)
                                    .foregroundStyle(Color.dashSecondary)
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

    private var monthlyTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportSectionHeader(title: "Monthly Trend", icon: "chart.line.uptrend.xyaxis")

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
                    .symbolSize(30)
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
    private func reportSectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dashSleep)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.dashLabel)
        }
    }

    private var reportSummaryText: String {
        """
        Seizcare Seizure Report — \(duration.rawValue)
        Generated: \(Date().formatted(date: .long, time: .omitted))

        Total Events: \(totalCount)
        Avg Duration: \(avgDurationText)
        Top Trigger: \(mostCommonTrigger)
        Peak Time: \(records.peakTimeLabel)

        Severity Breakdown:
        \(severityData.map { "  \($0.label): \($0.count)" }.joined(separator: "\n"))
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
