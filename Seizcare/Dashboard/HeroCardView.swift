//
//  HeroCardView.swift
//  Seizcare
//

import SwiftUI
import Charts

struct HeroCardView: View {
    let records: [SeizureRecord]
    let heartRate: Double?
    let sleepHours: Double

    private var thisMonth: [SeizureRecord] {
        let cal = Calendar.current
        return records.filter { cal.isDate($0.startTime, equalTo: Date(), toGranularity: .month) }
    }

    private var lastMonth: [SeizureRecord] {
        let cal = Calendar.current
        guard let last = cal.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return records.filter { cal.isDate($0.startTime, equalTo: last, toGranularity: .month) }
    }

    private var trendDiff: Int { thisMonth.count - lastMonth.count }
    private var trendValue: String { trendDiff == 0 ? "same" : (trendDiff > 0 ? "+\(trendDiff)" : "\(trendDiff)") }
    private var trendIcon: String { trendDiff == 0 ? "minus" : (trendDiff > 0 ? "arrow.up.right" : "arrow.down.right") }
    private var trendColor: Color { trendDiff == 0 ? .dashSecondary : (trendDiff > 0 ? .dashSeizure : .dashGreen) }

    private var avgSleep: Double { sleepHours }

    private var avgDuration: String {
        let secs = thisMonth.averageDurationSeconds
        if secs == 0 { return "—" }
        let mins = Int(secs / 60)
        return mins > 0 ? "\(mins)m" : "<1m"
    }


    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(alignment: .top) {
                if records.isEmpty && sleepHours == 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ready_to_track")
                            .font(.appTitle)
                            .foregroundStyle(Color.dashLabel)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("this_month")
                            .font(.appCaption)
                            .foregroundStyle(Color.dashSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(records.isEmpty ? "--" : "\(thisMonth.count)")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(Color.dashLabel)
                            Text("seizures")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.dashSecondary)
                                .offset(y: -4)
                        }
                    }
                }

                Spacer()
            }

            Spacer().frame(height: 28)

            // Stats row
            if records.isEmpty && avgSleep == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.dashSecondary.opacity(0.6))
                    Text("no_data_available")
                        .font(.appFootnote)
                        .foregroundStyle(Color.dashSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 0) {
                    StatPill(
                        icon: "moon.zzz.fill",
                        label: "avg_sleep",
                        value: avgSleep > 0 ? String(format: "%.1fh", avgSleep) : "—",
                        color: .dashSleep
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Color.dashTertiary)
                        .padding(.horizontal, 12)
                    StatPill(
                        icon: "timer",
                        label: "avg_duration_stat",
                        value: avgDuration,
                        color: .dashSecondary
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Color.dashTertiary)
                        .padding(.horizontal, 12)
                    StatPill(
                        icon: trendIcon,
                        label: "vs_last_month",
                        value: records.isEmpty ? (trendDiff == 0 ? "same" : trendValue) : trendValue,
                        color: trendColor
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Color.dashTertiary)
                        .padding(.horizontal, 12)
                    StatPill(
                        icon: "heart.fill",
                        label: "current_hr",
                        value: (heartRate ?? 0) > 0 ? "\(Int(heartRate ?? 0))" : "—",
                        color: .dashSeizure
                    )
                }
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
                .font(.appFootnote)
                .foregroundStyle(color)
            Text(LocalizedStringKey(value))
                .font(.appCallout.weight(.bold))
                .foregroundStyle(Color.dashLabel)
            Text(LocalizedStringKey(label))
                .font(.appCaption)
                .foregroundStyle(Color.dashSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
