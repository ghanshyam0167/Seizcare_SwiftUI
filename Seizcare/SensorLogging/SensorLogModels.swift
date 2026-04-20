//
//  SensorLogModels.swift
//  Seizcare
//
//  Watch → iPhone → Supabase logging payloads.
//

import Foundation

// MARK: - Watch Payloads (Watch → iPhone)

/// A single sensor sample captured on Apple Watch.
///
/// Note: We send timestamps as epoch seconds to keep the Watch payload compact and stable.
/// The iPhone converts to ISO8601 for Supabase insertion.
struct WatchSensorSamplePayload: Codable, Hashable {
    let timestamp: Double               // epoch seconds
    let heartRate: Int                  // BPM
    let accelX: Float
    let accelY: Float
    let accelZ: Float
    let gyroX: Float
    let gyroY: Float
    let gyroZ: Float
    let activityLabel: String?
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case heartRate = "heart_rate"
        case accelX = "accel_x"
        case accelY = "accel_y"
        case accelZ = "accel_z"
        case gyroX  = "gyro_x"
        case gyroY  = "gyro_y"
        case gyroZ  = "gyro_z"
        case activityLabel = "activity_label"
    }
}

/// A batched payload sent from Watch to iPhone every few seconds.
struct WatchSensorBatchPayload: Codable, Hashable {
    let batchId: UUID
    let sentAt: Double                  // epoch seconds
    let samples: [WatchSensorSamplePayload]
    let deviceSource: String            // "watch"
    
    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case sentAt = "sent_at"
        case samples
        case deviceSource = "device_source"
    }
}

// MARK: - Supabase Insert Row (iPhone → Supabase)

/// Row inserted into `seizure_sensor_logs` via Supabase REST.
struct SeizureSensorLogInsert: Codable, Hashable {
    let userId: UUID
    let timestamp: String               // ISO8601 (timestamptz)
    let heartRate: Int
    let accelX: Float
    let accelY: Float
    let accelZ: Float
    let gyroX: Float
    let gyroY: Float
    let gyroZ: Float
    let activityLabel: String?
    let deviceSource: String            // "watch"
    let seizureEvent: Bool              // default false
    let sessionId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case timestamp
        case heartRate = "heart_rate"
        case accelX = "accel_x"
        case accelY = "accel_y"
        case accelZ = "accel_z"
        case gyroX  = "gyro_x"
        case gyroY  = "gyro_y"
        case gyroZ  = "gyro_z"
        case activityLabel = "activity_label"
        case deviceSource = "device_source"
        case seizureEvent = "seizure_event"
        case sessionId = "session_id"
    }
}

// MARK: - Date Formatting

enum SensorLogDateFormat {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    static func iso8601String(epochSeconds: Double) -> String {
        iso8601.string(from: Date(timeIntervalSince1970: epochSeconds))
    }
}

