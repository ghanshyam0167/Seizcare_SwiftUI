//
//  SeizureRecordService.swift
//  Seizcare
//

import Foundation

final class SeizureRecordService {
    private let rest: SupabaseRESTClient
    private let iso = ISO8601DateFormatter()

    init(rest: SupabaseRESTClient? = nil) {
        self.rest = rest ?? SupabaseRESTClient()
    }

    /// Inserts an auto-detected seizure record stub (end_time/type/triggers are NULL initially).
    func insertAutoDetectedDemoRecord(userId: UUID, startTime: Date = Date()) async throws -> SeizureRecord {
        struct InsertRow: Encodable {
            let id: String
            let user_id: String
            let entry_type: String
            let start_time: String
            let end_time: String?
            let severity_type: String?
            let triggers: [String]?
            let location: String?
            let notes: String?
        }

        let recordId = UUID()
        let row = InsertRow(
            id: recordId.uuidString.lowercased(),
            user_id: userId.uuidString.lowercased(),
            entry_type: EntryType.automatic.rawValue,
            start_time: iso.string(from: startTime),
            end_time: nil,
            severity_type: nil,
            triggers: nil,
            location: nil,
            notes: "Auto detected (Demo Mode)"
        )

        let body = try JSONEncoder().encode([row])
        _ = try await rest.request(
            "POST",
            path: "rest/v1/seizure_records",
            queryItems: [],
            jsonBody: body,
            prefer: "return=minimal"
        )

        return SeizureRecord(
            id: recordId,
            userId: userId,
            entryType: .automatic,
            startTime: startTime,
            endTime: nil,
            type: nil,
            triggers: [],
            location: nil,
            notes: "Auto detected (Demo Mode)"
        )
    }

    /// Fetches the most recent ongoing seizure record (end_time IS NULL), if any.
    func fetchLatestOngoingRecord(userId: UUID) async throws -> SeizureRecord? {
        let data = try await rest.request(
            "GET",
            path: "rest/v1/seizure_records",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString.lowercased())"),
                URLQueryItem(name: "end_time", value: "is.null"),
                URLQueryItem(name: "order", value: "start_time.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([SeizureRecord].self, from: data)
        return rows.first
    }
}
