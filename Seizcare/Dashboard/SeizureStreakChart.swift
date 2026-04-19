//
//  SeizureStreakChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Mini Preview

struct SeizureStreakMiniChart: View {
    let records: [SeizureRecord]
    
    private var daysSinceLast: Int {
        let sorted = records.sorted { $0.endTime > $1.endTime }
        guard let last = sorted.first?.endTime else { return 0 }
        let cal = Calendar.current
        let components = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date()))
        return max(0, components.day ?? 0)
    }

    private var last7Days: [(date: Date, hasSeizure: Bool)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let start = cal.startOfDay(for: day)
            guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, sCount > 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(daysSinceLast)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.dashGreen)
                Text("days_free")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dashSecondary)
            }
            
            HStack(spacing: 4) {
                ForEach(last7Days, id: \.date) { item in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.hasSeizure ? Color.dashSeizure.opacity(0.8) : Color.dashGreen.opacity(0.25))
                        if !item.hasSeizure {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(Color.dashGreen)
                        }
                    }
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Full Screen Detail

struct SeizureStreakChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]

    private var currentStreak: Int {
        let sorted = records.sorted { $0.endTime > $1.endTime }
        guard let last = sorted.first?.endTime else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day ?? 0)
    }

    private var longestStreak: Int {
        guard records.count > 1 else { return currentStreak }
        let sorted = records.sorted { $0.startTime < $1.startTime }
        var maxStreak = 0
        let cal = Calendar.current
        
        for i in 1..<sorted.count {
            let prev = cal.startOfDay(for: sorted[i-1].endTime)
            let curr = cal.startOfDay(for: sorted[i].startTime)
            let gap = cal.dateComponents([.day], from: prev, to: curr).day ?? 0
            if gap > maxStreak { maxStreak = gap }
        }
        
        if currentStreak > maxStreak { maxStreak = currentStreak }
        return maxStreak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary row
                    HStack(spacing: 0) {
                        SummaryTile(label: "current_streak", value: String(localized: "streak_days \(currentStreak)"))
                            .foregroundStyle(Color.dashGreen)
                        SummaryTile(label: "longest_streak", value: String(localized: "streak_days \(longestStreak)"))
                            .foregroundStyle(Color.dashLabel)
                    }
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Insight Card
                    HStack(spacing: 14) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.dashGreen)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentStreak == 0 ? "keep_going" : "doing_great")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.dashLabel)
                            Text(currentStreak == 0 
                                 ? String(localized: "streak_start_today") 
                                 : String(localized: "streak_congrats \(currentStreak)"))
                                .font(.caption)
                                .foregroundStyle(Color.dashSecondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Month Calendar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("thirty_day_outlook")
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(last30Days, id: \.date) { item in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(item.hasSeizure ? Color.dashSeizure.opacity(0.8) : Color.dashGreen.opacity(0.15))
                                        .aspectRatio(1.0, contentMode: .fit)
                                    
                                    if !item.hasSeizure {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.dashGreen)
                                    } else {
                                        Text("\(item.count)")
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(16)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("seizure_free_streak")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundStyle(Color.dashGreen)
                }
            }
        }
    }
    
    private var last30Days: [(date: Date, count: Int, hasSeizure: Bool)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<30).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let start = cal.startOfDay(for: day)
            guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, sCount, sCount > 0)
        }
    }
}

private struct SummaryTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(LocalizedStringKey(label))
                .font(.caption)
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
