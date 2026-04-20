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
    
    var localizationKey: String {
        rawValue.lowercased()
    }
}

enum SeizureType: String, Codable, CaseIterable {
    case mild, moderate, severe

    var displayName: String {
        localizationKey.localized
    }

    var localizationKey: String {
        rawValue.lowercased()
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
    /// Stored as `auto-detected` in the database to match backend naming.
    case automatic = "auto-detected"
    case manual = "manual"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self))?.lowercased() ?? ""
        switch raw {
        case "auto-detected", "automatic", "auto_detected", "auto":
            self = .automatic
        case "manual":
            self = .manual
        default:
            // Be permissive for forward-compat; treat unknown values as manual.
            self = .manual
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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

    var localizationKey: String {
        rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Models

struct SeizureRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let entryType: EntryType
    let startTime: Date
    let endTime: Date?
    let type: SeizureType?
    let triggers: [SeizureTrigger]
    let location: String?
    let notes: String?

    // Derived — not stored
    /// For ongoing (endTime == nil) records, we treat duration as time since start.
    var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }
    var isOngoing: Bool { endTime == nil }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case entryType = "entry_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case type = "severity_type"
        case triggers
        case location
        case notes
    }
    
    init(
        id: UUID,
        userId: UUID,
        entryType: EntryType,
        startTime: Date,
        endTime: Date?,
        type: SeizureType?,
        triggers: [SeizureTrigger],
        location: String?,
        notes: String?
    ) {
        self.id = id
        self.userId = userId
        self.entryType = entryType
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.triggers = triggers
        self.location = location
        self.notes = notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        entryType = try container.decode(EntryType.self, forKey: .entryType)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        type = try container.decodeIfPresent(SeizureType.self, forKey: .type)
        
        // Supabase can return `triggers` as null for auto-detected stubs; treat as empty.
        triggers = (try? container.decode([SeizureTrigger].self, forKey: .triggers)) ?? []
        
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct HeartRateSample: Identifiable, Codable {
    let id: UUID
    let userId: UUID?      // nil for HealthKit-sourced samples
    let timestamp: Date
    let bpm: Int
    let recordId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case timestamp
        case bpm
        case recordId = "record_id"
    }
}

struct SleepRecord: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let hours: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date = "sleep_date"
        case hours = "duration_hours"
    }
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

        // Manual entries — user logged these themselves
        let manualEntries: [(dayOffset: Int, hour: Int, durationMin: Int, type: SeizureType, triggers: [SeizureTrigger], notes: String?, location: String?)] = [
            (-28, 8,  3,  .mild,     [.stress],           "Felt slight aura before onset. Recovered quickly.", "Home - Living Room"),
            (-22, 20, 15, .moderate, [.stress],           "Happened after a stressful work call. Rested for 30 mins after.", nil),
            (-13, 11, 7,  .moderate, [.flashingLights],   "At the cinema. Lights on screen may have triggered it.", "Cineplex Mall"),
            (-3,  10, 5,  .mild,     [.stress],           "Minor episode. Was feeling anxious before it started.", "Office"),
        ]

        for e in manualEntries {
            guard let day   = calendar.date(byAdding: .day, value: e.dayOffset, to: now),
                  let start = calendar.date(bySettingHour: e.hour, minute: 0, second: 0, of: day),
                  let end   = calendar.date(byAdding: .minute, value: e.durationMin, to: start)
            else { continue }
            records.append(SeizureRecord(
                id: UUID(), userId: userId,
                entryType: .manual,
                startTime: start, endTime: end,
                type: e.type, triggers: e.triggers,
                location: e.location, notes: e.notes
            ))
        }

        // Automatic entries — detected by Apple Watch / HealthKit
        let autoEntries: [(dayOffset: Int, hour: Int, minute: Int, durationMin: Int, type: SeizureType, triggers: [SeizureTrigger], location: String?)] = [
            (-26, 14, 23, 8,  .moderate, [.poorSleep, .stress],      "Bedroom"),
            (-24, 22, 47, 12, .severe,   [.missedMedication],        "Home"),
            (-17, 9,  11, 5,  .mild,     [.stress],                  "Gym"),
            (-15, 16, 55, 20, .severe,   [.poorSleep, .missedMedication], "Home - Bedroom"),
            (-10, 8,  34, 4,  .moderate, [.stress, .poorSleep],      "Home"),
            (-8,  19, 2,  6,  .mild,     [.exercise],                "Park"),
            (-6,  13, 18, 8,  .mild,     [.stress],                  "Office"),
            (-1,  15, 41, 12, .moderate, [.poorSleep],               "Home"),
        ]

        for e in autoEntries {
            guard let day   = calendar.date(byAdding: .day, value: e.dayOffset, to: now),
                  let start = calendar.date(bySettingHour: e.hour, minute: e.minute, second: 0, of: day),
                  let end   = calendar.date(byAdding: .minute, value: e.durationMin, to: start)
            else { continue }
            records.append(SeizureRecord(
                id: UUID(), userId: userId,
                entryType: .automatic,
                startTime: start, endTime: end,
                type: e.type, triggers: e.triggers,
                location: e.location, notes: "Automatically detected via Apple Watch. Heart rate spike and motion pattern confirmed seizure activity."
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
            return SleepRecord(id: UUID(), userId: userId, date: date, hours: hoursPattern[offset % 7])
        }
    }()

    static func heartRateSamples(for record: SeizureRecord) -> [HeartRateSample] {
        let endTime = record.endTime ?? Date()
        let windowStart = record.startTime.addingTimeInterval(-3600)
        let windowEnd   = endTime.addingTimeInterval(3600)
        let interval: TimeInterval = 120

        var samples: [HeartRateSample] = []
        var current = windowStart
        while current <= windowEnd {
            let bpm: Int
            if current < record.startTime {
                let progress = max(0, current.timeIntervalSince(windowStart)) / 3600
                bpm = Int(68 + progress * 17) + Int.random(in: -3...3)
            } else if current <= endTime {
                let dur = max(record.duration, 1)
                let p   = current.timeIntervalSince(record.startTime) / dur
                bpm = Int(85 + sin(p * .pi) * 70) + Int.random(in: -5...5)
            } else {
                let minutesAfter = current.timeIntervalSince(endTime) / 60
                let p            = min(minutesAfter / 60.0, 1.0)
                bpm = Int(150 - p * 80) + Int.random(in: -4...4)
            }
            samples.append(HeartRateSample(id: UUID(), userId: userId, timestamp: current, bpm: max(50, min(180, bpm)), recordId: record.id))
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
        return hourlyCounts(over: 24)
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
        return dailyCounts(over: 7)
    }

    func thisMonthDailyCounts() -> [(date: Date, count: Int)] {
        return dailyCounts(over: 30)
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
        return monthlyCounts(over: 12)
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
            ("morning",   morning,   .dashSleep),
            ("afternoon", afternoon, Color(red: 0.8, green: 0.6, blue: 1.0)),
            ("evening",   evening,   .dashSeizure),
            ("night",     night,     Color(red: 0.4, green: 0.8, blue: 0.6)),
        ]
    }

    var peakTimeKey: String {
        let sorted = timeOfDayCounts().max(by: { $0.count < $1.count })
        return sorted?.label ?? "—"
    }
}
