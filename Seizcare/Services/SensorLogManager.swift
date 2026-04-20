//
//  SensorLogManager.swift
//  Seizcare
//

import Foundation
import Combine

@MainActor
final class SensorLogManager: ObservableObject {
    static let shared = SensorLogManager()

    struct ActiveTaggingSession: Equatable {
        let userId: UUID
        let recordId: UUID
        let startedAt: Date
        let expiresAt: Date
    }

    @Published private(set) var activeSession: ActiveTaggingSession? = nil

    private let rest: SupabaseRESTClient
    private let iso = ISO8601DateFormatter()
    private var taggingTask: Task<Void, Never>?

    init(rest: SupabaseRESTClient? = nil) {
        self.rest = rest ?? SupabaseRESTClient()
    }

    func fetchLatestHeartRate(userId: UUID) async throws -> Int? {
        struct HRRow: Decodable { let heart_rate: Int? }

        let data = try await rest.request(
            "GET",
            path: "rest/v1/seizure_sensor_logs",
            queryItems: [
                URLQueryItem(name: "select", value: "heart_rate,timestamp"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString.lowercased())"),
                URLQueryItem(name: "heart_rate", value: "not.is.null"),
                URLQueryItem(name: "order", value: "timestamp.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )

        let decoder = JSONDecoder()
        let rows = try decoder.decode([HRRow].self, from: data)
        return rows.first?.heart_rate
    }

    /// Tags existing logs from `since` onward to belong to the given seizure record.
    func tagLogs(userId: UUID, recordId: UUID, since: Date) async throws {
        struct Patch: Encodable {
            let seizure_event: Bool
            let session_id: String
        }
        let patch = Patch(seizure_event: true, session_id: recordId.uuidString.lowercased())
        let body = try JSONEncoder().encode(patch)

        _ = try await rest.request(
            "PATCH",
            path: "rest/v1/seizure_sensor_logs",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString.lowercased())"),
                URLQueryItem(name: "timestamp", value: "gte.\(iso.string(from: since))"),
                // Avoid overwriting other tagged sessions.
                URLQueryItem(name: "session_id", value: "is.null"),
            ],
            jsonBody: body,
            prefer: "return=minimal"
        )
    }

    /// Starts tagging: retro-tags the last 2 hours and keeps re-tagging fresh logs until stop or expiry.
    func startTagging(userId: UUID, recordId: UUID, startedAt: Date = Date(), maxDuration: TimeInterval = 2 * 60 * 60) {
        let now = Date()
        let session = ActiveTaggingSession(
            userId: userId,
            recordId: recordId,
            startedAt: startedAt,
            expiresAt: now.addingTimeInterval(maxDuration)
        )

        activeSession = session
        taggingTask?.cancel()

        taggingTask = Task { [weak self] in
            guard let self else { return }
            do {
                // 1) Tag the last 2 hours.
                try await self.tagLogs(userId: userId, recordId: recordId, since: now.addingTimeInterval(-2 * 60 * 60))
            } catch {
                print("⚠️ [SensorLogManager] Initial retro-tag failed:", error.localizedDescription)
            }

            // 2) Keep tagging fresh incoming logs (safety net).
            var lastPatch = Date()
            while !Task.isCancelled {
                if Date() >= session.expiresAt { break }
                do {
                    // Overlap by 10s to avoid timestamp edge misses.
                    let since = lastPatch.addingTimeInterval(-10)
                    try await self.tagLogs(userId: userId, recordId: recordId, since: since)
                } catch {
                    print("⚠️ [SensorLogManager] Continuous tag failed:", error.localizedDescription)
                }
                lastPatch = Date()
                try? await Task.sleep(for: .seconds(30))
            }

            await MainActor.run {
                self.stopTagging(recordId: recordId)
            }
        }
    }

    func stopTagging(recordId: UUID) {
        guard activeSession?.recordId == recordId else { return }
        taggingTask?.cancel()
        taggingTask = nil
        activeSession = nil
    }
}
