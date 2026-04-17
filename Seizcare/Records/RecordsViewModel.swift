//
//  RecordsViewModel.swift
//  Seizcare
//

import SwiftUI
import Combine

// MARK: - Records View Model

@MainActor
final class RecordsViewModel: ObservableObject {

    // All records (source of truth)
    @Published var records: [SeizureRecord] = MockDashboardData.seizureRecords

    // Search
    @Published var searchQuery: String = ""

    // Sheet states
    @Published var showAddRecord: Bool = false
    @Published var recordToEdit: SeizureRecord? = nil

    // Computed: filtered records
    var filteredRecords: [SeizureRecord] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return records
        }
        let q = searchQuery.lowercased()
        
        // Format to allow searching by full month, shortened month, day, or year
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy MMM d"
        
        return records.filter { record in
            let notesMatch    = record.notes?.lowercased().contains(q) ?? false
            let triggerMatch  = record.triggers.contains { $0.rawValue.lowercased().contains(q) }
            let typeMatch     = record.type.displayName.lowercased().contains(q)
            let dateMatch     = dateFormatter.string(from: record.startTime).lowercased().contains(q)
            
            return notesMatch || triggerMatch || typeMatch || dateMatch
        }
    }

    // Grouped by month header string
    var groupedRecords: [(month: String, records: [SeizureRecord])] {
        let sorted = filteredRecords.sorted { $0.startTime > $1.startTime }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var dict: [(month: String, records: [SeizureRecord])] = []
        var seenMonths: [String] = []

        for record in sorted {
            let key = formatter.string(from: record.startTime)
            if let idx = seenMonths.firstIndex(of: key) {
                dict[idx].records.append(record)
            } else {
                seenMonths.append(key)
                dict.append((month: key, records: [record]))
            }
        }
        return dict
    }

    // MARK: - CRUD

    func addRecord(_ record: SeizureRecord) {
        records.insert(record, at: 0)
        records.sort { $0.startTime > $1.startTime }
    }

    func updateRecord(_ updated: SeizureRecord) {
        if let idx = records.firstIndex(where: { $0.id == updated.id }) {
            records[idx] = updated
        }
        records.sort { $0.startTime > $1.startTime }
    }

    func deleteRecord(_ record: SeizureRecord) {
        records.removeAll { $0.id == record.id }
    }
}
