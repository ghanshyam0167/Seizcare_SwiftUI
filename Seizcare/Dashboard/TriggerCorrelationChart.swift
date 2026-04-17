//
//  TriggerCorrelationChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Mini Preview

struct TriggerCorrelationMiniChart: View {
    let records: [SeizureRecord]
    
    private var data: [(trigger: SeizureTrigger, percentage: Double)] {
        Array(records.triggerFrequency().prefix(2))
    }

    var body: some View {
        VStack(spacing: 5) {
            if let top = data.first {
                HStack(spacing: 4) {
                    Text("\(top.trigger.rawValue)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                    Text("is top trigger")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dashSecondary)
                    Spacer()
                }
                .padding(.bottom, 2)
            } else {
                Text("No data").font(.caption).foregroundStyle(Color.dashSecondary)
            }
            
            ForEach(data, id: \.trigger) { item in
                VStack(spacing: 2) {
                    HStack {
                        Text(item.trigger.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.dashSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%%", item.percentage))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.dashLabel)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.15))
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.8))
                                .frame(width: geo.size.width * (item.percentage / 100))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }
}

// MARK: - Full Screen

struct TriggerCorrelationChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]

    private var data: [(trigger: SeizureTrigger, percentage: Double)] {
        records.triggerFrequency()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if data.isEmpty {
                        EmptyStateCard(message: "No trigger data recorded yet")
                    } else {
                        // Horizontal bar chart
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trigger Correlation — % of seizures")
                                .font(.caption)
                                .foregroundStyle(Color.dashSecondary)

                            Chart(data, id: \.trigger) { item in
                                BarMark(
                                    x: .value("Percentage", item.percentage),
                                    y: .value("Trigger",    item.trigger.rawValue)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.dashSeizure, Color.dashSeizure.opacity(0.5)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .cornerRadius(6)
                                .annotation(position: .trailing) {
                                    Text(String(format: "%.0f%%", item.percentage))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(Color.dashSecondary)
                                        .padding(.leading, 4)
                                }
                            }
                            .chartXScale(domain: 0...100)
                            .chartXAxis {
                                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                                    AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.3))
                                    AxisValueLabel {
                                        if let v = value.as(Int.self) {
                                            Text("\(v)%")
                                                .font(.caption2)
                                                .foregroundStyle(Color.dashTertiary)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks { _ in
                                    AxisValueLabel()
                                        .foregroundStyle(Color.dashLabel)
                                }
                            }
                            .frame(height: CGFloat(data.count) * 44 + 40)
                        }
                        .padding(16)
                        .background(Color.dashCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Detailed rows with context
                        VStack(spacing: 10) {
                            ForEach(data.prefix(5), id: \.trigger) { item in
                                TriggerDetailRow(item: item, total: records.count)
                            }
                        }
                        .padding(16)
                        .background(Color.dashCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Top trigger insight
                        if let top = data.first {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.dashSeizure)
                                Text("\"\(top.trigger.rawValue)\" is your most common trigger, present in \(Int(top.percentage))% of events.")
                                    .font(.caption)
                                    .foregroundStyle(Color.dashSecondary)
                            }
                            .padding(16)
                            .background(Color.dashCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("Trigger Analysis")
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

private struct TriggerDetailRow: View {
    let item: (trigger: SeizureTrigger, percentage: Double)
    let total: Int
    private var count: Int { Int(item.percentage * Double(total) / 100) }

    var body: some View {
        HStack {
            Text(item.trigger.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.dashLabel)
            Spacer()
            Text("\(count) events")
                .font(.caption)
                .foregroundStyle(Color.dashSecondary)
            Text(String(format: "%.0f%%", item.percentage))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dashSeizure)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
