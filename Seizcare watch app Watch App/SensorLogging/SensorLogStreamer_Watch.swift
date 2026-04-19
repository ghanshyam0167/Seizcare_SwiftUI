//
//  SensorLogStreamer_Watch.swift
//  Seizcare watch app Watch App
//
//  Collects HR + motion and sends batched sensor logs to the paired iPhone.
//

import Foundation
import WatchConnectivity
import Combine

// MARK: - Payload Models (must match iOS decoding)

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

// MARK: - Streamer

final class SensorLogStreamer_Watch {
    private let syncQueue = DispatchQueue(label: "sensorlog.streamer.queue")
    private var flushTimer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()
    
    private var latestHeartRateBpm: Int = 0
    private var latestActivityLabel: String? = nil
    private var buffer: [WatchSensorSamplePayload] = []
    
    // Battery/throughput tuning
    private let batchInterval: TimeInterval = 8.0     // 5–10 seconds requirement (use 8s default)
    private let maxSamplesPerBatch: Int = 2500        // safety cap
    
    init(connectivity: WatchConnectivityManager = .shared) {
        // Keep a rolling HR value that we stamp onto each motion sample.
        connectivity.$heartRate
            .receive(on: syncQueue)
            .sink { [weak self] hr in
                self?.latestHeartRateBpm = max(0, Int(hr.rounded()))
            }
            .store(in: &cancellables)
        
        // If you later implement motion activity on watch, update `latestActivityLabel` here.
        connectivity.$isStreaming
            .receive(on: syncQueue)
            .sink { [weak self] streaming in
                if !streaming {
                    self?.buffer.removeAll(keepingCapacity: true)
                }
            }
            .store(in: &cancellables)
    }
    
    func start() {
        syncQueue.async { [weak self] in
            guard let self else { return }
            guard self.flushTimer == nil else { return }
            
            let t = DispatchSource.makeTimerSource(queue: self.syncQueue)
            t.schedule(deadline: .now() + self.batchInterval, repeating: self.batchInterval)
            t.setEventHandler { [weak self] in
                self?.flush()
            }
            t.resume()
            self.flushTimer = t
        }
    }
    
    func stop() {
        syncQueue.async { [weak self] in
            self?.flush()
            self?.flushTimer?.cancel()
            self?.flushTimer = nil
            self?.buffer.removeAll(keepingCapacity: true)
        }
    }
    
    func handleMotionPoint(_ p: MotionDataPoint) {
        syncQueue.async { [weak self] in
            guard let self else { return }
            guard WatchConnectivityManager.shared.isStreaming else { return }
            
            // DeviceMotion timestamps are relative to boot; use absolute time for training logs.
            let ts = Date().timeIntervalSince1970
            let sample = WatchSensorSamplePayload(
                timestamp: ts,
                heartRate: self.latestHeartRateBpm,
                accelX: Float(p.accX),
                accelY: Float(p.accY),
                accelZ: Float(p.accZ),
                gyroX: Float(p.rotX),
                gyroY: Float(p.rotY),
                gyroZ: Float(p.rotZ),
                activityLabel: self.latestActivityLabel
            )
            self.buffer.append(sample)
            
            // Safety cap to avoid unbounded growth if the phone is unreachable for a while.
            if self.buffer.count > self.maxSamplesPerBatch * 3 {
                self.buffer.removeFirst(self.buffer.count - self.maxSamplesPerBatch * 3)
            }
        }
    }
    
    private func flush() {
        guard !buffer.isEmpty else { return }
        let batchSamples = Array(buffer.prefix(maxSamplesPerBatch))
        buffer.removeFirst(min(buffer.count, maxSamplesPerBatch))
        
        let payload = WatchSensorBatchPayload(
            batchId: UUID(),
            sentAt: Date().timeIntervalSince1970,
            samples: batchSamples,
            deviceSource: "watch"
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            sendToPhone(data)
        } catch {
            print("⚠️ [SensorLogStreamer] encode failed:", error.localizedDescription)
        }
    }
    
    private func sendToPhone(_ data: Data) {
        let session = WCSession.default
        guard WCSession.isSupported() else { return }
        guard session.activationState == .activated else {
            // If not activated yet, just drop; next flush will try again.
            return
        }
        
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { error in
                // If immediate delivery fails, fall back to queued delivery.
                print("⚠️ [SensorLogStreamer] sendMessageData failed:", error.localizedDescription)
                session.transferUserInfo(["sensor_batch": data])
            }
        } else {
            session.transferUserInfo(["sensor_batch": data])
        }
    }
}

