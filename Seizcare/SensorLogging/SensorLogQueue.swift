//
//  SensorLogQueue.swift
//  Seizcare
//
//  Durable local queue for Watch sensor logs (offline-first).
//

import Foundation

struct PendingSensorUpload: Codable, Hashable {
    let id: UUID
    let createdAt: Date
    var attempt: Int
    var nextAttemptAt: Date
    let rows: [SeizureSensorLogInsert]
}

struct SensorLogQueueEntry: Hashable {
    let fileURL: URL
    let upload: PendingSensorUpload
}

actor SensorLogQueue {
    static let shared = SensorLogQueue()
    
    private let fm = FileManager.default
    
    private init() {}
    
    // MARK: - Public API
    
    func enqueue(userId: UUID, rows: [SeizureSensorLogInsert]) async {
        guard !rows.isEmpty else { return }
        do {
            let dir = try queueDirectory(userId: userId)
            let id = UUID()
            let now = Date()
            let payload = PendingSensorUpload(
                id: id,
                createdAt: now,
                attempt: 0,
                nextAttemptAt: now,
                rows: rows
            )
            let fileURL = dir.appendingPathComponent(filename(for: payload))
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("⚠️ [SensorLogQueue] enqueue failed:", error.localizedDescription)
        }
    }
    
    func dueEntries(userId: UUID, now: Date = Date(), maxRows: Int = 2000) async -> [SensorLogQueueEntry] {
        do {
            let dir = try queueDirectory(userId: userId)
            let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            var picked: [SensorLogQueueEntry] = []
            var rowCount = 0
            
            for url in urls {
                let data = try Data(contentsOf: url)
                let upload = try JSONDecoder().decode(PendingSensorUpload.self, from: data)
                guard upload.nextAttemptAt <= now else { continue }
                
                if rowCount + upload.rows.count > maxRows, !picked.isEmpty {
                    break
                }
                
                picked.append(SensorLogQueueEntry(fileURL: url, upload: upload))
                rowCount += upload.rows.count
                
                if rowCount >= maxRows { break }
            }
            
            return picked
        } catch {
            print("⚠️ [SensorLogQueue] dueEntries failed:", error.localizedDescription)
            return []
        }
    }
    
    func markUploaded(_ entries: [SensorLogQueueEntry]) async {
        for e in entries {
            do {
                try fm.removeItem(at: e.fileURL)
            } catch {
                print("⚠️ [SensorLogQueue] removeItem failed:", error.localizedDescription)
            }
        }
    }
    
    func markFailed(_ entries: [SensorLogQueueEntry], now: Date = Date()) async {
        for e in entries {
            do {
                var next = e.upload
                next.attempt += 1
                next.nextAttemptAt = now.addingTimeInterval(backoffSeconds(attempt: next.attempt))
                let data = try JSONEncoder().encode(next)
                try data.write(to: e.fileURL, options: [.atomic])
            } catch {
                print("⚠️ [SensorLogQueue] markFailed write failed:", error.localizedDescription)
            }
        }
    }
    
    func pendingFileCount(userId: UUID) async -> Int {
        do {
            let dir = try queueDirectory(userId: userId)
            let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            return urls.filter { $0.pathExtension.lowercased() == "json" }.count
        } catch {
            return 0
        }
    }
    
    // MARK: - Internals
    
    private func filename(for upload: PendingSensorUpload) -> String {
        let epoch = Int(upload.createdAt.timeIntervalSince1970)
        return String(format: "batch_%010d_%@.json", epoch, upload.id.uuidString.lowercased())
    }
    
    private func queueDirectory(userId: UUID) throws -> URL {
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base
            .appendingPathComponent("SensorLogQueue", isDirectory: true)
            .appendingPathComponent(userId.uuidString.lowercased(), isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func backoffSeconds(attempt: Int) -> TimeInterval {
        // 5s, 10s, 20s, 40s... capped at 5 minutes + jitter.
        let base: TimeInterval = 5
        let capped = min(300, base * pow(2.0, Double(max(0, attempt - 1))))
        let jitter = Double.random(in: 0..<1.0)
        return capped + jitter
    }
}

