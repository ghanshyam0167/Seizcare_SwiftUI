//
//  SensorLogUploader.swift
//  Seizcare
//
//  Uploads queued Watch sensor logs to Supabase via REST.
//

import Foundation

enum SensorLogUploadError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}

final class SensorLogRestClient {
    func insertSensorLogs(rows: [SeizureSensorLogInsert], accessToken: String) async throws {
        guard !rows.isEmpty else { return }
        
        let url = SupabaseConfig.url
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
            .appendingPathComponent("seizure_sensor_logs")
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(rows)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if !(200...299).contains(code) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SensorLogUploadError.invalidResponse(code, body)
        }
    }
}

// MARK: - Session ID (ML grouping)

enum SensorLogSessionManager {
    private static func sessionIdKey(_ userId: UUID) -> String { "sensorlog_session_id_\(userId.uuidString.lowercased())" }
    private static func sessionStartKey(_ userId: UUID) -> String { "sensorlog_session_start_\(userId.uuidString.lowercased())" }
    
    /// Returns the current session_id for grouping continuous logs.
    /// Rotates the session every ~12 hours to keep sessions reasonably sized for ML batching.
    static func currentSessionId(userId: UUID, now: Date = Date()) -> UUID {
        let defaults = UserDefaults.standard
        if
            let sidStr = defaults.string(forKey: sessionIdKey(userId)),
            let sid = UUID(uuidString: sidStr),
            let start = defaults.object(forKey: sessionStartKey(userId)) as? Date,
            now.timeIntervalSince(start) < (12 * 60 * 60)
        {
            return sid
        }
        
        let newId = UUID()
        defaults.set(newId.uuidString.lowercased(), forKey: sessionIdKey(userId))
        defaults.set(now, forKey: sessionStartKey(userId))
        return newId
    }
}

// MARK: - Coordinator

actor SensorLogPipelineCoordinator {
    static let shared = SensorLogPipelineCoordinator()
    
    private let rest = SensorLogRestClient()
    private var isUploading = false
    
    private init() {}
    
    func ingestWatchBatch(_ batch: WatchSensorBatchPayload) async {
        guard let userId = (await SupabaseService.shared.currentUserId()) ?? cachedUserIdFromDefaults() else {
            print("⚠️ [SensorLog] Dropping batch \(batch.batchId) — user not logged in.")
            return
        }
        
        let sessionId = SensorLogSessionManager.currentSessionId(userId: userId)
        
        let rows: [SeizureSensorLogInsert] = batch.samples.map { s in
            SeizureSensorLogInsert(
                userId: userId,
                timestamp: SensorLogDateFormat.iso8601String(epochSeconds: s.timestamp),
                heartRate: s.heartRate,
                accelX: s.accelX,
                accelY: s.accelY,
                accelZ: s.accelZ,
                gyroX: s.gyroX,
                gyroY: s.gyroY,
                gyroZ: s.gyroZ,
                activityLabel: s.activityLabel,
                deviceSource: "watch",
                seizureEvent: false,
                sessionId: sessionId
            )
        }
        
        await SensorLogQueue.shared.enqueue(userId: userId, rows: rows)
        SensorLogBackgroundTasks.schedule()
        await kickUploadIfNeeded(userId: userId)
    }

    private func cachedUserIdFromDefaults() -> UUID? {
        // UserDataModel persists this key on login/restore. Using it avoids dropping batches
        // during a cold-start background delivery where the session isn't hydrated yet.
        guard let s = UserDefaults.standard.string(forKey: "currentUserId") else { return nil }
        return UUID(uuidString: s)
    }
    
    func kickUploadIfNeeded(userId: UUID? = nil) async {
        guard !isUploading else { return }
        let uid: UUID?
        if let userId {
            uid = userId
        } else {
            uid = await SupabaseService.shared.currentUserId()
        }
        guard let uid else { return }
        
        isUploading = true
        Task {
            _ = await self.uploadLoop(userId: uid)
        }
    }
    
    /// Runs an upload pass in a background task context (awaits completion).
    func performBackgroundUpload() async -> Bool {
        guard !isUploading else { return true }
        guard let uid = await SupabaseService.shared.currentUserId() else { return false }
        isUploading = true
        return await uploadLoop(userId: uid)
    }
    
    private func uploadLoop(userId: UUID) async -> Bool {
        defer { isUploading = false }
        
        while true {
            let entries = await SensorLogQueue.shared.dueEntries(userId: userId, maxRows: 2000)
            guard !entries.isEmpty else { return true }
            
            let rows = entries.flatMap { $0.upload.rows }
            
            do {
                let token = try await SupabaseService.shared.currentAccessToken()
                try await rest.insertSensorLogs(rows: rows, accessToken: token)
                await SensorLogQueue.shared.markUploaded(entries)
            } catch {
                print("⚠️ [SensorLog] Upload failed:", error.localizedDescription)
                await SensorLogQueue.shared.markFailed(entries)
                return false
            }
        }
    }
}
