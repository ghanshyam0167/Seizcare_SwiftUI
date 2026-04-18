//
//  SeizureFrequencyChart.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Mini Preview (used in GraphCard)

struct SeizureFrequencyMiniChart: View {
    let records: [SeizureRecord]
    let range: TimeFrameRange
    
    private var data: [(date: Date, count: Int)] {
        switch range {
        case .daily:   return records.thisDayHourlyCounts()
        case .weekly:  return records.thisWeekDailyCounts()
        case .monthly: return records.thisMonthDailyCounts()
        case .yearly:  return records.thisYearMonthlyCounts()
        }
    }

    private var totalInView: Int { data.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dateLabel(for: range))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.dashSecondary)
            
            Text("\(totalInView)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.cyan)
                .padding(.bottom, 4)
            
            let barUnit: Calendar.Component = {
                switch range {
                case .daily: return .hour
                case .weekly: return .day
                case .monthly: return .day
                case .yearly: return .month
                }
            }()
            
            let maxCount = Double(data.map(\.count).max() ?? 0)
            let yDomain = maxCount == 0 ? 1.0 : maxCount * 1.2
            
            Chart(data, id: \.date) { point in
                if point.count == 0 {
                    BarMark(
                        x: .value("Time", point.date, unit: barUnit),
                        y: .value("Count", yDomain * 0.95),
                        width: .fixed(1.5)
                    )
                    .foregroundStyle(Color.gray.opacity(0.15))
                    .cornerRadius(1)
                } else {
                    BarMark(
                        x: .value("Time", point.date, unit: barUnit),
                        y: .value("Count", Double(point.count)),
                        width: .fixed(1.5)
                    )
                    .foregroundStyle(Color.cyan)
                    .cornerRadius(1)
                }
            }
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisValues(for: range)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date, range: range))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.dashSecondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...yDomain)
            .frame(height: 70)
        }
    }
}

// MARK: - Fileprivate Helpers

fileprivate func dateLabel(for range: TimeFrameRange) -> String {
    switch range {
    case .daily: return "Today"
    case .weekly: return "This Week"
    case .monthly:
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: Date()).uppercased()
    case .yearly:
        let f = DateFormatter(); f.dateFormat = "yyyy"
        return f.string(from: Date())
    }
}

fileprivate func xAxisValues(for range: TimeFrameRange) -> [Date] {
    let cal = Calendar.current
    var dates: [Date] = []
    let now = Date()
    
    switch range {
    case .daily:
        let start = cal.startOfDay(for: now)
        for h in [0, 6, 12, 18] { if let d = cal.date(byAdding: .hour, value: h, to: start) { dates.append(d) } }
    case .weekly:
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        if let start = cal.date(from: comps) {
            for d in 0..<7 { if let dt = cal.date(byAdding: .day, value: d, to: start) { dates.append(dt) } }
        }
    case .monthly:
        let comps = cal.dateComponents([.year, .month], from: now)
        if let start = cal.date(from: comps) {
            for d in [0, 7, 14, 21, 28] { if let dt = cal.date(byAdding: .day, value: d, to: start) { dates.append(dt) } }
        }
    case .yearly:
        let year = cal.component(.year, from: now)
        if let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) {
            for m in 0..<12 { if let dt = cal.date(byAdding: .month, value: m, to: start) { dates.append(dt) } }
        }
    }
    return dates
}

fileprivate func xAxisLabel(for date: Date, range: TimeFrameRange) -> String {
    let f = DateFormatter()
    switch range {
    case .daily: f.dateFormat = "h a"; return f.string(from: date)
    case .weekly: f.dateFormat = "EEE"; return f.string(from: date).capitalized
    case .monthly: f.dateFormat = "d"; return f.string(from: date)
    case .yearly: f.dateFormat = "MMM"; return String(f.string(from: date).prefix(1)).uppercased()
    }
}

// MARK: - Full Screen Detail

struct SeizureFrequencyChartView: View {
    @Environment(\.dismiss) private var dismiss
    let records: [SeizureRecord]
    @State var initialRange: TimeFrameRange

    @State private var selectedDate: Date?

    private var data: [(date: Date, count: Int)] {
        switch initialRange {
        case .daily:   return records.thisDayHourlyCounts()
        case .weekly:  return records.thisWeekDailyCounts()
        case .monthly: return records.thisMonthDailyCounts()
        case .yearly:  return records.thisYearMonthlyCounts()
        }
    }
    
    private var totalInView: Int { data.reduce(0) { $0 + $1.count } }
    private var peakInView: Int { data.map(\.count).max() ?? 0 }

    private var filteredRecords: [SeizureRecord] {
        let cal = Calendar.current
        let now = Date()
        switch initialRange {
        case .daily:
            return records.filter { cal.isDate($0.startTime, inSameDayAs: now) }
        case .weekly:
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2 // Monday
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .day, value: 7, to: start) else { return [] }
            return records.filter { $0.startTime >= start && $0.startTime < end }
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: now)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return [] }
            return records.filter { $0.startTime >= start && $0.startTime < end }
        case .yearly:
            let year = cal.component(.year, from: now)
            guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let end = cal.date(byAdding: .year, value: 1, to: start) else { return [] }
            return records.filter { $0.startTime >= start && $0.startTime < end }
        }
    }
    
    private var selectedPoint: (date: Date, count: Int)? {
        guard let selectedDate else { return nil }
        let cal = Calendar.current
        let pt = data.first(where: {
            let start = $0.date
            let end: Date
            switch initialRange {
            case .daily: end = cal.date(byAdding: .hour, value: 1, to: start)!
            case .weekly, .monthly: end = cal.date(byAdding: .day, value: 1, to: start)!
            case .yearly: end = cal.date(byAdding: .month, value: 1, to: start)!
            }
            return selectedDate >= start && selectedDate < end
        })
        if let pt = pt, pt.count > 0 {
            return pt
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Segmented Picker
                        Picker("Range", selection: $initialRange) {
                            ForEach(TimeFrameRange.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // Header Metrics
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headerTitle(for: initialRange))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.dashSecondary)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                let valString: String = {
                                    if initialRange == .daily {
                                        return "\(totalInView)"
                                    } else {
                                        let avg = Double(totalInView) / divisor(for: initialRange)
                                        return "\(Int(round(avg)))"
                                    }
                                }()
                                Text(valString)
                                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.cyan)
                                Text("EVENTS")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.cyan)
                            }
                            
                            Text(dateLabel(for: initialRange))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.dashSecondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 75, alignment: .bottomLeading)
                        .opacity(selectedPoint != nil ? 0 : 1)
                        
                        // Main Chart
                        let barUnit: Calendar.Component = {
                            switch initialRange {
                            case .daily: return .hour
                            case .weekly: return .day
                            case .monthly: return .day
                            case .yearly: return .month
                            }
                        }()
                        
                        Chart(data, id: \.date) { point in
                            BarMark(
                                x: .value("Time", point.date, unit: barUnit),
                                y: .value("Count", point.count)
                            )
                            .foregroundStyle(selectedPoint == nil || selectedPoint?.date == point.date ? Color.cyan : Color.cyan.opacity(0.3))
                            
                            if let selectedPoint, selectedPoint.date == point.date {
                                RuleMark(x: .value("Time", point.date, unit: barUnit))
                                    .foregroundStyle(Color.cyan.opacity(0.5))
                                    .offset(yStart: -10)
                                    .zIndex(-1)
                                    .annotation(
                                        position: .top,
                                        spacing: 0,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                                    ) {
                                        VStack(spacing: 4) {
                                            Text("TOTAL")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.white.opacity(0.8))
                                            Text("\(selectedPoint.count)")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(tooltipDateLabel(for: selectedPoint.date, range: initialRange))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.cyan.opacity(0.8))
                                        .cornerRadius(8)
                                    }
                            }
                        }
                        .chartXSelection(value: $selectedDate)
                        .chartXScale(range: .plotDimension(padding: 20))
                        .chartYScale(domain: 0...(peakInView == 0 ? 5 : Int(Double(peakInView) * 1.35 + 1)))
                        .chartXAxis {
                            AxisMarks(preset: .aligned, values: xAxisValues(for: initialRange)) { value in
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(xAxisLabel(for: date, range: initialRange))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                AxisValueLabel(anchor: .bottomLeading) {
                                    if let intVal = value.as(Int.self) {
                                        Text("\(intVal)")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.gray)
                                            .padding(.bottom, 2)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding(.horizontal, 20)
                        
                        // Padding out
                        Spacer().frame(height: 30)

                        // Type breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event Breakdown")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.dashLabel)
                            TypeBreakdownView(records: filteredRecords)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle("Event Frequency")
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
    
    // MARK: - Helpers
    
    private func durationForPoint(_ pt: (date: Date, count: Int)) -> TimeInterval {
        let cal = Calendar.current
        let start = pt.date
        let end: Date
        switch initialRange {
        case .daily: end = cal.date(byAdding: .hour, value: 1, to: start)!
        case .weekly, .monthly: end = cal.date(byAdding: .day, value: 1, to: start)!
        case .yearly: end = cal.date(byAdding: .month, value: 1, to: start)!
        }
        let matched = records.filter { $0.startTime >= start && $0.startTime < end }
        return matched.reduce(0) { $0 + $1.duration }
    }
    
    private func exactDateLabel(for date: Date, range: TimeFrameRange) -> String {
        let f = DateFormatter()
        switch range {
        case .daily:
            f.dateFormat = "h a"
            let start = f.string(from: date)
            let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
            let end = f.string(from: endDate)
            return "\(start) - \(end)"
        case .weekly, .monthly:
            f.dateFormat = "EEEE, MMM d, yyyy"
            return f.string(from: date)
        case .yearly:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: date)
        }
    }
    
    private func tooltipDateLabel(for date: Date, range: TimeFrameRange) -> String {
        let f = DateFormatter()
        switch range {
        case .daily:
            f.dateFormat = "h a"
            let start = f.string(from: date)
            let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date)!
            let end = f.string(from: endDate)
            return "\(start) - \(end)"
        case .weekly, .monthly:
            f.dateFormat = "d MMM yyyy"
            return f.string(from: date)
        case .yearly:
            f.dateFormat = "MMM yyyy"
            return f.string(from: date)
        }
    }
    
    private func headerTitle(for range: TimeFrameRange) -> String {
        switch range {
        case .daily: return "TOTAL"
        case .weekly: return "DAILY AVERAGE"
        case .monthly: return "DAILY AVERAGE"
        case .yearly: return "MONTHLY AVERAGE"
        }
    }
    
    private func divisor(for range: TimeFrameRange) -> Double {
        let cal = Calendar.current
        let now = Date()
        switch range {
        case .daily: return 1
        case .weekly: 
            let weekday = cal.component(.weekday, from: now)
            let mondayBased = (weekday + 5) % 7 + 1
            return Double(mondayBased)
        case .monthly: 
            return Double(cal.component(.day, from: now))
        case .yearly: 
            return Double(cal.component(.month, from: now))
        }
    }
    

}

private struct TypeBreakdownView: View {
    let records: [SeizureRecord]
    private var breakdown: [(type: SeizureType, count: Int)] {
        SeizureType.allCases.map { t in (t, records.filter { $0.type == t }.count) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Severity")
                .font(.caption)
                .foregroundStyle(Color.dashSecondary)
            ForEach(breakdown, id: \.type) { item in
                HStack(spacing: 12) {
                    SeverityBadge(type: item.type)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(item.type.color.opacity(0.15)).frame(height: 8)
                            let w = records.isEmpty ? 0 : geo.size.width * Double(item.count) / Double(records.count)
                            Capsule().fill(item.type.color).frame(width: w, height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text("\(item.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.dashLabel)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SummaryTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}
