//
//  DashboardModels.swift
//  Seizcare
//

import Foundation
import SwiftUI

// MARK: - Enums

enum TimeFrameRange: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    var id: String { rawValue }
}

enum SeizureType: String, Codable, CaseIterable {
    case mild, moderate, severe

    var displayName: String {
        switch self {
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .severe:   return "Severe"
        }
    }

    var color: Color {
        switch self {
        case .mild:     return Color(red: 1.0, green: 0.80, blue: 0.0)
        case .moderate: return Color(red: 1.0, green: 0.50, blue: 0.0)
        case .severe:   return Color(red: 1.0, green: 0.26, blue: 0.26)
        }
    }
}

enum EntryType: String, Codable {
    case automatic, manual
}

enum SeizureTrigger: String, Codable, CaseIterable, Identifiable {
    case stress           = "Stress"
    case poorSleep        = "Poor Sleep"
    case alcohol          = "Alcohol"
    case exercise         = "Exercise"
    case flashingLights   = "Flashing Lights"
    case missedMedication = "Missed Medication"
    case unknown          = "Unknown"

    var id: String { rawValue }
}

// MARK: - Models

struct SeizureRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let entryType: EntryType
    let startTime: Date
    let endTime: Date
    let type: SeizureType
    let triggers: [SeizureTrigger]
    let location: String?
    let notes: String?

    // Derived — not stored
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
}

struct HeartRateSample: Identifiable {
    let id: UUID
    let timestamp: Date
    let bpm: Int
    let recordId: UUID?
}

struct SleepRecord: Identifiable {
    let id: UUID
    let date: Date
    let hours: Double
}

// MARK: - Design tokens

extension Color {
    // Dynamic Colors utilizing iOS TraitCollection
    static let dashBg = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
    })
    
    static let dashCard = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })
    
    static let dashCardElevated = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })
    
    static let dashLabel = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor.black
    })
    
    static let dashSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.65, alpha: 1.0)
            : UIColor(white: 0.45, alpha: 1.0)
    })
    
    static let dashTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.35, alpha: 1.0)
            : UIColor(white: 0.85, alpha: 1.0)
    })
    
    // Core brand/state colors remain consistent across themes (or mildly adjusted)
    static let dashSeizure       = Color(red: 1.0,  green: 0.27, blue: 0.27)
    static let dashSleep         = Color(red: 0.25, green: 0.60, blue: 1.0)
    static let dashGreen         = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let dashPurple        = Color(red: 0.58, green: 0.44, blue: 1.0)
}

// MARK: - Mock Data

struct MockDashboardData {
    static let userId = UUID()

    static let seizureRecords: [SeizureRecord] = {
        let calendar = Calendar.current
        let now = Date()
        var records: [SeizureRecord] = []

        let entries: [(dayOffset: Int, hour: Int, durationMin: Int, type: SeizureType, triggers: [SeizureTrigger])] = [
            (-28, 8,  3,  .mild,     [.stress]),
            (-26, 14, 8,  .moderate, [.poorSleep, .stress]),
            (-24, 22, 12, .severe,   [.missedMedication]),
            (-22, 7,  2,  .mild,     [.exercise]),
            (-22, 20, 15, .moderate, [.stress]),
            (-17, 9,  5,  .mild,     [.stress]),
            (-15, 16, 20, .severe,   [.poorSleep, .missedMedication]),
            (-13, 11, 7,  .moderate, [.flashingLights]),
            (-12, 23, 10, .mild,     [.alcohol]),
            (-10, 8,  4,  .moderate, [.stress, .poorSleep]),
            (-8,  19, 6,  .mild,     [.exercise]),
            (-6,  13, 8,  .mild,     [.stress]),
            (-3,  10, 5,  .mild,     [.stress]),
            (-1,  15, 12, .moderate, [.poorSleep]),
        ]

        for e in entries {
            guard let day   = calendar.date(byAdding: .day, value: e.dayOffset, to: now),
                  let start = calendar.date(bySettingHour: e.hour, minute: 0, second: 0, of: day),
                  let end   = calendar.date(byAdding: .minute, value: e.durationMin, to: start)
            else { continue }

            records.append(SeizureRecord(
                id: UUID(), userId: userId,
                entryType: .manual,
                startTime: start, endTime: end,
                type: e.type, triggers: e.triggers,
                location: nil, notes: nil
            ))
        }
        return records.sorted { $0.startTime > $1.startTime }
    }()

    static let sleepRecords: [SleepRecord] = {
        let calendar = Calendar.current
        let now = Date()
        let hoursPattern: [Double] = [5.5, 6.0, 7.5, 8.0, 6.5, 5.0, 7.0]
        return (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return SleepRecord(id: UUID(), date: date, hours: hoursPattern[offset % 7])
        }
    }()

    static func heartRateSamples(for record: SeizureRecord) -> [HeartRateSample] {
        let windowStart = record.startTime.addingTimeInterval(-3600)
        let windowEnd   = record.endTime.addingTimeInterval(3600)
        let interval: TimeInterval = 120

        var samples: [HeartRateSample] = []
        var current = windowStart
        while current <= windowEnd {
            let bpm: Int
            if current < record.startTime {
                let progress = max(0, current.timeIntervalSince(windowStart)) / 3600
                bpm = Int(68 + progress * 17) + Int.random(in: -3...3)
            } else if current <= record.endTime {
                let dur = max(record.duration, 1)
                let p   = current.timeIntervalSince(record.startTime) / dur
                bpm = Int(85 + sin(p * .pi) * 70) + Int.random(in: -5...5)
            } else {
                let minutesAfter = current.timeIntervalSince(record.endTime) / 60
                let p            = min(minutesAfter / 60.0, 1.0)
                bpm = Int(150 - p * 80) + Int.random(in: -4...4)
            }
            samples.append(HeartRateSample(
                id: UUID(), timestamp: current,
                bpm: max(50, min(180, bpm)), recordId: record.id
            ))
            current = current.addingTimeInterval(interval)
        }
        return samples
    }
}

// MARK: - Array helpers

extension Array where Element == SeizureRecord {
    func hourlyCounts(over hours: Int) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<hours).reversed().compactMap { offset -> (Date, Int)? in
            guard let hour = calendar.date(byAdding: .hour, value: -offset, to: now) else { return nil }
            let start = calendar.date(bySetting: .minute, value: 0, of: hour) ?? hour
            guard let end = calendar.date(byAdding: .hour, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }

    func thisDayHourlyCounts() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return (0..<24).compactMap { hourOffset -> (Date, Int)? in
            guard let start = calendar.date(byAdding: .hour, value: hourOffset, to: startOfToday),
                  let end = calendar.date(byAdding: .hour, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }

    func dailyCounts(over days: Int) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now      = Date()
        return (0..<days).reversed().compactMap { offset -> (Date, Int)? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }

    func thisWeekDailyCounts() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        // Find Monday of the current week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        guard let startOfMonday = calendar.date(from: components) else {
            // Fallback if weekday calculation fails
            return dailyCounts(over: 7)
        }
        
        return (0..<7).compactMap { dayOffset -> (Date, Int)? in
            guard let start = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonday),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }

    func thisMonthDailyCounts() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return dailyCounts(over: 30)
        }
        
        return (0..<range.count).compactMap { dayOffset -> (Date, Int)? in
            guard let start = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }
    
    func monthlyCounts(over months: Int) -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<months).reversed().compactMap { offset -> (Date, Int)? in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let components = calendar.dateComponents([.year, .month], from: month)
            guard let start = calendar.date(from: components),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }
    
    func thisYearMonthlyCounts() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return monthlyCounts(over: 12)
        }
        
        return (0..<12).compactMap { monthOffset -> (Date, Int)? in
            guard let start = calendar.date(byAdding: .month, value: monthOffset, to: startOfYear),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let count = filter { $0.startTime >= start && $0.startTime < end }.count
            return (start, count)
        }
    }

    var averageDurationSeconds: TimeInterval {
        guard !isEmpty else { return 0 }
        return reduce(0) { $0 + $1.duration } / Double(count)
    }

    func triggerFrequency() -> [(trigger: SeizureTrigger, percentage: Double)] {
        guard !isEmpty else { return [] }
        var counts: [SeizureTrigger: Int] = [:]
        for r in self { for t in r.triggers { counts[t, default: 0] += 1 } }
        let total = Double(count)
        return counts.map { ($0.key, Double($0.value) / total * 100) }
                     .sorted { $0.percentage > $1.percentage }
    }

    func timeOfDayCounts() -> [(label: String, count: Int, color: Color)] {
        let cal = Calendar.current
        var morning = 0, afternoon = 0, evening = 0, night = 0
        for r in self {
            let h = cal.component(.hour, from: r.startTime)
            switch h {
            case 5..<12:  morning   += 1
            case 12..<17: afternoon += 1
            case 17..<21: evening   += 1
            default:      night     += 1
            }
        }
        return [
            ("Morning",   morning,   .dashSleep),
            ("Afternoon", afternoon, Color(red: 0.8, green: 0.6, blue: 1.0)),
            ("Evening",   evening,   .dashSeizure),
            ("Night",     night,     Color(red: 0.4, green: 0.8, blue: 0.6)),
        ]
    }

    var peakTimeLabel: String {
        let sorted = timeOfDayCounts().max(by: { $0.count < $1.count })
        return sorted?.label ?? "—"
    }
}
