//
//  RecordsViewModel.swift
//  Seizcare
//

import SwiftUI
import Combine

// MARK: - Filter Models

enum RecordGrouping: String, CaseIterable, Identifiable {
    case all        = "All"
    case bySeverity = "Severity"
    case byTrigger  = "Trigger"
    case byMonth    = "Month"
    var id: String { rawValue }
}

enum DurationBucket: String, CaseIterable, Identifiable {
    case lt5    = "< 5 min"
    case m5to10 = "5–10 min"
    case gt10   = "> 10 min"
    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .lt5:    return "lt_5_min"
        case .m5to10: return "5_10_min"
        case .gt10:   return "gt_10_min"
        }
    }

    func matches(_ interval: TimeInterval) -> Bool {
        let mins = interval / 60
        switch self {
        case .lt5:    return mins < 5
        case .m5to10: return mins >= 5 && mins <= 10
        case .gt10:   return mins > 10
        }
    }
}

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case last7  = "Last 7 Days"
    case last30 = "Last 30 Days"
    case custom = "Custom"
    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .last7:  return "last_7_days"
        case .last30: return "last_30_days"
        case .custom: return "custom"
        }
    }
}

struct RecordFilter {
    var severities: Set<SeizureType>    = []
    var triggers:   Set<SeizureTrigger> = []
    var durations:  Set<DurationBucket> = []
    var dateRange:  DateRangeFilter?    = nil
    var customStart: Date               = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var customEnd:   Date               = Date()

    var isActive: Bool {
        !severities.isEmpty || !triggers.isEmpty || !durations.isEmpty || dateRange != nil
    }

    var activeChips: [String] {
        var chips: [String] = []
        chips += severities.map { $0.displayName }
        chips += triggers.map { $0.rawValue }
        chips += durations.map { $0.rawValue }
        if let dr = dateRange { chips.append(dr.rawValue) }
        return chips
    }

    func matches(_ record: SeizureRecord) -> Bool {
        if !severities.isEmpty, !severities.contains(record.type) { return false }
        if !triggers.isEmpty, !triggers.contains(where: { record.triggers.contains($0) }) { return false }
        if !durations.isEmpty, !durations.contains(where: { $0.matches(record.duration) }) { return false }
        if let dr = dateRange {
            let now = Date()
            switch dr {
            case .last7:
                guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) else { break }
                if record.startTime < cutoff { return false }
            case .last30:
                guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) else { break }
                if record.startTime < cutoff { return false }
            case .custom:
                if record.startTime < customStart || record.startTime > customEnd { return false }
            }
        }
        return true
    }

    mutating func reset() {
        severities = []
        triggers = []
        durations = []
        dateRange = nil
        customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        customEnd = Date()
    }

    mutating func removeChip(_ chip: String) {
        if let s = severities.first(where: { $0.displayName == chip }) {
            severities.remove(s)
            return
        }
        if let t = triggers.first(where: { $0.rawValue == chip }) {
            triggers.remove(t)
            return
        }
        if let d = durations.first(where: { $0.rawValue == chip }) {
            durations.remove(d)
            return
        }
        if dateRange?.rawValue == chip {
            dateRange = nil
            return
        }
    }
}

// MARK: - Records View Model

@MainActor
final class RecordsViewModel: ObservableObject {

    // All records (source of truth)
    @Published var records: [SeizureRecord] = []

    // Loading / error state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Search
    @Published var searchQuery: String = ""

    // Filter & grouping
    @Published var filter: RecordFilter = RecordFilter()
    @Published var grouping: RecordGrouping = .byMonth

    // Sheet states
    @Published var showAddRecord: Bool = false
    @Published var showFilterSheet: Bool = false
    @Published var showReportOptions: Bool = false
    @Published var recordToEdit: SeizureRecord? = nil

    init() {
        Task { await fetchRecords() }
    }

    // MARK: - Fetch

    func fetchRecords() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let userId = await SupabaseService.shared.currentUserId() else {
            // Not logged in yet
            records = []
            return
        }

        do {
            records = try await SupabaseService.shared.fetchSeizureRecords(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            if records.isEmpty { records = [] }
        }
    }

    // MARK: - Computed: search + filter applied

    var filteredRecords: [SeizureRecord] {
        var base = records

        // Search
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM d, yyyy MMM d"
            base = base.filter { r in
                let notesMatch   = r.notes?.lowercased().contains(q) ?? false
                let triggerMatch = r.triggers.contains { $0.rawValue.lowercased().contains(q) }
                let typeMatch    = r.type.displayName.lowercased().contains(q)
                let dateMatch    = fmt.string(from: r.startTime).lowercased().contains(q)
                return notesMatch || triggerMatch || typeMatch || dateMatch
            }
        }

        // Filters
        if filter.isActive {
            base = base.filter { filter.matches($0) }
        }

        return base.sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Grouped records (for list display)

    var groupedRecords: [(header: String, records: [SeizureRecord])] {
        let sorted = filteredRecords
        switch grouping {
        case .all:
            return sorted.isEmpty ? [] : [("all_records", sorted)]

        case .byMonth:
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: UserDefaults.standard.string(forKey: "app_language") ?? "en")
            fmt.dateFormat = "MMMM yyyy"
            return group(sorted, by: { fmt.string(from: $0.startTime) })

        case .bySeverity:
            return SeizureType.allCases.compactMap { type in
                let matching = sorted.filter { $0.type == type }
                return matching.isEmpty ? nil : (type.displayName, matching)
            }

        case .byTrigger:
            var result: [(header: String, records: [SeizureRecord])] = []
            var seen = Set<String>()
            for record in sorted {
                let label = record.triggers.first?.rawValue ?? "unknown"
                if !seen.contains(label) {
                    seen.insert(label)
                    result.append((label, sorted.filter {
                        ($0.triggers.first?.rawValue ?? "unknown") == label
                    }))
                }
            }
            return result
        }
    }

    private func group(_ records: [SeizureRecord], by key: (SeizureRecord) -> String) -> [(header: String, records: [SeizureRecord])] {
        var result: [(header: String, records: [SeizureRecord])] = []
        var seen: [String] = []
        for r in records {
            let k = key(r)
            if let idx = seen.firstIndex(of: k) {
                result[idx].records.append(r)
            } else {
                seen.append(k)
                result.append((k, [r]))
            }
        }
        return result
    }

    // MARK: - CRUD (Optimistic local update + background Supabase sync)

    func addRecord(_ record: SeizureRecord) {
        // Optimistic update
        records.insert(record, at: 0)
        records.sort { $0.startTime > $1.startTime }

        Task {
            do {
                try await SupabaseService.shared.insertSeizureRecord(record)
            } catch {
                // Rollback on failure
                records.removeAll { $0.id == record.id }
                errorMessage = "Failed to save record: \(error.localizedDescription)"
            }
        }
    }

    func updateRecord(_ updated: SeizureRecord) {
        // Optimistic update
        if let idx = records.firstIndex(where: { $0.id == updated.id }) {
            records[idx] = updated
        }
        records.sort { $0.startTime > $1.startTime }

        Task {
            do {
                try await SupabaseService.shared.updateSeizureRecord(updated)
            } catch {
                // Refresh from server to restore correct state
                errorMessage = "Failed to update record: \(error.localizedDescription)"
                await fetchRecords()
            }
        }
    }

    func deleteRecord(_ record: SeizureRecord) {
        // Optimistic update
        records.removeAll { $0.id == record.id }

        Task {
            do {
                try await SupabaseService.shared.deleteSeizureRecord(id: record.id)
            } catch {
                // Re-insert on failure
                records.append(record)
                records.sort { $0.startTime > $1.startTime }
                errorMessage = "Failed to delete record: \(error.localizedDescription)"
            }
        }
    }
}
