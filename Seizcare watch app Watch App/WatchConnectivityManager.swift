//
//  WatchConnectivityManager.swift
//  SeizcareWatch
//

import Foundation
import WatchConnectivity
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    @Published var heartRate: Double = 0
    @Published var spo2: Double = 0
    @Published var sleepHours: Double = 0
    @Published var isStreaming: Bool = true
    @Published var sensitivity: Int = 1 // 0: low, 1: medium, 2: high
    @Published var isAlarmActive: Bool = false
    @Published var userId: String? = nil
    @Published var accessToken: String? = nil
    
    // Freshness Tracking
    @Published var heartRateTimestamp: Date?
    @Published var spo2Timestamp: Date?
    @Published var isHeartRateFresh: Bool = false
    @Published var isSpO2Fresh: Bool = false

    @Published private(set) var lastValidHeartRate: Double?
    private(set) var lastUpdateTime: Date?
    private var staleLogBucket: Int = -1

    private let spo2FreshnessThreshold: TimeInterval = 300 // 5 minutes
    private var stalenessTimer: AnyCancellable?

    var displayHeartRateText: String {
        if let lastValidHeartRate {
            return "\(Int(lastValidHeartRate))"
        }
        return "Waiting..."
    }

    var hasHeartRateValue: Bool {
        lastValidHeartRate != nil
    }
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("[Watch] WCSession initiated")
        }
        
        // Listen to local HealthKit on Watch
        HealthKitManager_Watch.shared.heartRateUpdateHandler = { [weak self] bpm in
            self?.sendLocalHRtoPhone(bpm)
        }
        
        startStalenessChecker()
    }
    
    private func startStalenessChecker() {
        stalenessTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkFreshness()
            }
    }
    
    private func checkFreshness() {
        let now = Date()

        isHeartRateFresh = hasHeartRateValue
        logHeartRateStalenessIfNeeded(referenceDate: now)
        
        // SpO2 Validity
        if let spo2Ts = spo2Timestamp {
            let age = now.timeIntervalSince(spo2Ts)
            let fresh = age < spo2FreshnessThreshold && spo2 > 0
            if isSpO2Fresh != fresh {
                isSpO2Fresh = fresh
                print("[Watch] SpO2 Freshness changed: \(fresh) (age: \(Int(age))s)")
            }
        } else {
            isSpO2Fresh = false
        }
    }

    private func logHeartRateStalenessIfNeeded(referenceDate: Date = Date()) {
        guard let lastUpdateTime else {
            return
        }

        let age = referenceDate.timeIntervalSince(lastUpdateTime)
        guard age >= 15 else {
            staleLogBucket = -1
            return
        }

        let bucket = Int(age / 15)
        guard bucket != staleLogBucket else {
            return
        }

        staleLogBucket = bucket
        print("[HR] Data stale (\(Int(age))s since last update)")
        print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
    }

    private func recordHeartRateUpdate(_ bpm: Double) {
        lastUpdateTime = Date()
        heartRateTimestamp = lastUpdateTime
        staleLogBucket = -1

        if bpm > 0 {
            heartRate = bpm
            lastValidHeartRate = bpm
        } else if let lastValidHeartRate {
            heartRate = lastValidHeartRate
        }

        print("[HR] New value: \(bpm)")
        print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
        checkFreshness()
    }
    
    private func sendLocalHRtoPhone(_ bpm: Double) {
        guard isStreaming else {
            return
        }

        print("[WC] Sent HR change to Phone: \(Int(bpm)) BPM")
        print("[WC] Sending HR: \(bpm)")
        
        DispatchQueue.main.async {
            self.recordHeartRateUpdate(bpm)
        }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["heartRate": bpm], replyHandler: nil) { error in
                print("[ERROR] \(error.localizedDescription)")
                print("[WC] Error sending local HR: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WC] Session activated: \(activationState.rawValue)")
        if let error = error {
            print("[ERROR] \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("[WC] Message received")
        print("[Watch] Message received: \(message)")
        
        DispatchQueue.main.async {
            if let hr = message["heartRate"] as? Double {
                print("[Watch] Received HR: \(hr)")
                self.recordHeartRateUpdate(hr)
            }
            
            if let sleep = message["sleepHours"] as? Double {
                self.sleepHours = sleep
                print("[Watch] Received Sleep: \(sleep)")
            }
            
            if let spo2 = message["spo2"] as? Double {
                self.spo2 = spo2
                self.spo2Timestamp = Date()
                print("[Watch] Received SpO2: \(spo2)")
            }
            
            self.checkFreshness()
            
            if let levelString = message["sensitivity"] as? String {
                self.sensitivity = self.mapSensitivityStringToInt(levelString)
                print("[Watch] Received sensitivity: \(levelString) (\(self.sensitivity))")
            }
            
            if let uid = message["userId"] as? String {
                self.userId = uid
                print("[Watch] Received User ID: \(uid)")
            }

            if let token = message["accessToken"] as? String {
                self.accessToken = token
                print("[Watch] Received Access Token (JWT) [Synced]")
            }
            
            if let action = message["action"] as? String {
                if action == "stopAlarm" {
                    print("[Watch] Remote stopAlarm received!")
                    self.isAlarmActive = false
                } else if action == "forceTrigger" {
                    print("[Watch] Received forceTrigger from Phone")
                    DetectionPipelineManager.shared.forceTrigger = true
                } else if action == "stopTagging" {
                    print("[Watch] Received stopTagging from Phone")
                    DetectionPipelineManager.shared.stopTaggingLogs()
                }
            }
        }
    }
    
    // Fallback: values sent via updateApplicationContext arrive here
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("[Watch] Received applicationContext: \(applicationContext)")
        DispatchQueue.main.async {
            if let spo2 = applicationContext["spo2"] as? Double {
                self.spo2 = spo2
                self.spo2Timestamp = Date()
                print("[Watch] SpO2 from context: \(spo2)")
            }
            if let hr = applicationContext["heartRate"] as? Double {
                self.recordHeartRateUpdate(hr)
            }
            self.checkFreshness()
            if let sleep = applicationContext["sleepHours"] as? Double {
                self.sleepHours = sleep
            }
            if let levelString = applicationContext["sensitivity"] as? String {
                self.sensitivity = self.mapSensitivityStringToInt(levelString)
                print("[Watch] Context sensitivity: \(levelString)")
            }
            if let uid = applicationContext["userId"] as? String {
                self.userId = uid
                print("[Watch] Context User ID: \(uid)")
            }
            if let token = applicationContext["accessToken"] as? String {
                self.accessToken = token
                print("[Watch] Context Access Token (JWT) [Synced]")
            }
            if let action = applicationContext["action"] as? String {
                if action == "stopAlarm" {
                    self.isAlarmActive = false
                }
            }
        }
    }
    
    func startStreaming() {
        print("[Watch] Requesting Start Stream")
        WCSession.default.sendMessage(["action": "startStream"], replyHandler: nil) { error in
            print("[Watch] Error sending startStream: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isStreaming = true
        }
        HealthKitManager_Watch.shared.startHeartRateStreaming()
    }
    
    func stopStreaming() {
        print("[Watch] Requesting Stop Stream")
        WCSession.default.sendMessage(["action": "stopStream"], replyHandler: nil) { error in
            print("[Watch] Error sending stopStream: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isStreaming = false
        }
        HealthKitManager_Watch.shared.stopHeartRateStreaming()
    }
    
    func updateSensitivity(_ value: Int) {
        let levelString = mapSensitivityIntToString(value)
        print("[Watch] Syncing sensitivity to phone: \(levelString)")
        
        DispatchQueue.main.async {
            self.sensitivity = value
        }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["sensitivity": levelString], replyHandler: nil) { error in
                print("[Watch] Error syncing sensitivity: \(error.localizedDescription)")
            }
        }
    }
    
    private func mapSensitivityStringToInt(_ level: String) -> Int {
        switch level.lowercased() {
        case "low": return 0
        case "high": return 2
        default: return 1 // medium
        }
    }
    
    func triggerEmergencyAlert() {
        print("[WATCH-SOS] Triggering background emergency alert transfer...")
        DispatchQueue.main.async { self.isAlarmActive = true }
        
        let userInfo: [String: Any] = ["type": "seizure_alert"]
        print("[WATCH-SOS] Sending background alert: \(userInfo)")
        
        // Background-safe delivery
        WCSession.default.transferUserInfo(userInfo)
        
        // Also send interactive message if reachable as a secondary path
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(userInfo, replyHandler: nil) { error in
                print("[WATCH-SOS] Foreground message failed (Phone likely backgrounded): \(error.localizedDescription)")
            }
        }
    }
    
    func sendStopAlarmToPhone() {
        print("[Watch-SOS] Sending stopAlarm to Phone")
        DispatchQueue.main.async { self.isAlarmActive = false }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "stopAlarm"], replyHandler: nil) { error in
                print("[ERROR] Failed to send stopAlarm to phone: \(error.localizedDescription)")
            }
        }
    }
    
    private func mapSensitivityIntToString(_ value: Int) -> String {
        switch value {
        case 0: return "low"
        case 2: return "high"
        default: return "medium"
        }
    }
}
