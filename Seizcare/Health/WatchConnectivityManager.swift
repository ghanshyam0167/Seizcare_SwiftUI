//
//  WatchConnectivityManager.swift
//  Seizcare
//

import Foundation
import WatchConnectivity
import CoreLocation
import Combine
import UIKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isAppInstalled: Bool = false
    @Published var isStreaming: Bool = false
    @Published var isWaitingForFirstSample: Bool = false
    
    private var lastStreamTimestamp: Date?
    private var streamTimer: Timer?

    /// Merged context dict — all keys (spo2, sleepHours, heartRate) live here together.
    /// updateApplicationContext REPLACES the whole dict, so we must send all keys every time.
    private var sharedContext: [String: Any] = [:]
    
    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?

    private override init() {
        super.init()
        
        // Setup Location for emergency triggers from Watch
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            print("[WC] Session initialized on iOS")
        }
        
        // Start a slow timer to check stream status (every 5s)
        streamTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkStreamStatus()
        }
    }

    private func ensureLocationAuthorization() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .notDetermined {
            // Prompt only when we actually need location (e.g. Watch-triggered SOS),
            // to avoid surprise permissions during app launch.
            locationManager.requestAlwaysAuthorization()
        }
    }

    private func checkStreamStatus() {
        guard let lastTs = lastStreamTimestamp else {
            if isStreaming { isStreaming = false }
            return
        }
        
        let age = Date().timeIntervalSince(lastTs)
        let isNowStreaming = age < 15.0
        print("[STREAM] Last update: \(lastTs)")
        print("[STREAM] Active: \(isNowStreaming)")
        
        if isStreaming != isNowStreaming {
            DispatchQueue.main.async {
                self.isStreaming = isNowStreaming
                if !isNowStreaming {
                    self.isWaitingForFirstSample = false
                }
            }
        }
    }

    // MARK: - Private context helper

    /// Merges `updates` into sharedContext and pushes the FULL dict to Watch.
    private func pushContext(_ updates: [String: Any]) {
        for (key, value) in updates {
            sharedContext[key] = value
        }
        
        guard WCSession.default.activationState == .activated else {
            print("[WC] pushContext: session not activated yet, value cached in sharedContext: \(updates)")
            return
        }
        
        do {
            try WCSession.default.updateApplicationContext(sharedContext)
            print("[WC] Context pushed: \(sharedContext)")
        } catch {
            print("[ERROR] \(error.localizedDescription)")
            print("[WC] Context push error: \(error.localizedDescription)")
        }
    }

    // MARK: - API

    func sendHeartRateToWatch(_ value: Double) {
        print("[WC] Sending HR: \(value)")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["heartRate": value], replyHandler: nil) { error in
                print("[ERROR] \(error.localizedDescription)")
                print("[WC] Error sending HR: \(error.localizedDescription)")
            }
            print("[WC] Sent HR live: \(value)")
        }
        pushContext(["heartRate": value])
    }
    
    func sendStopAlarmToWatch() {
        print("[WC] Sending stopAlarm command to Watch")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "stopAlarm"], replyHandler: nil) { error in
                print("[ERROR] Failed to send stopAlarm to Watch: \(error.localizedDescription)")
            }
        }
        // Also push via context for eventual consistency
        pushContext(["action": "stopAlarm"])
    }

    func sendSpO2ToWatch(_ value: Double) {
        guard value > 0 else {
            print("[WC] SpO2 value 0 — skipping send")
            return
        }
        print("[SYNC-VERIFY] Sending SpO2: \(value)%")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["spo2": value], replyHandler: nil) { error in
                print("[WC] Error sending SpO2: \(error.localizedDescription)")
            }
        }
        pushContext(["spo2": value])
    }

    func sendSleepToWatch(_ value: Double) {
        print("[SYNC-VERIFY] Sending Sleep: \(value) hrs")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["sleepHours": value], replyHandler: nil) { error in
                print("[WC] Error sending Sleep: \(error.localizedDescription)")
            }
            print("[WC] Sent Sleep live: \(value)")
        } else {
            print("[WC] Watch not reachable — Sleep queued in context")
        }
        pushContext(["sleepHours": value])
    }

    func sendSensitivityToWatch(_ level: String) {
        print("[SYNC-VERIFY] Sending Sensitivity: \(level)")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["sensitivity": level], replyHandler: nil) { error in
                print("[WC] Error sending Sensitivity: \(error.localizedDescription)")
            }
        }
        pushContext(["sensitivity": level])
    }

    /// Backward-compatible alias
    func sendSleepDataToWatch(_ sleep: Double) { sendSleepToWatch(sleep) }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WC] Session activated: \(activationState.rawValue)")
        if let error = error {
            print("[ERROR] \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isAppInstalled = session.isWatchAppInstalled
        }
        
        // Re-push the full context 1 second after activation so Watch gets all values on reconnect
        if !sharedContext.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.pushContext([:])
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WC] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[WC] Session deactivated. Re-activating...")
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[WC] Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("[WC] Watch state changed: Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled)")
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isAppInstalled = session.isWatchAppInstalled
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WC] Message received")
        print("[WC] Received message from Watch: \(message)")
        print("[WC] Reachable: \(session.isReachable)")

        if let hr = message["heartRate"] as? Double {
            print("[WC] Direct HR from Watch: \(hr)")
            
            // Mark stream as active if HR is coming (and not 0)
            if hr > 0 {
                lastStreamTimestamp = Date()
                DispatchQueue.main.async {
                    self.isStreaming = true
                    self.isWaitingForFirstSample = false
                }
            }
            
            NotificationCenter.default.post(
                name: NSNotification.Name("WatchHeartRateUpdate"),
                object: nil,
                userInfo: ["bpm": hr]
            )
        }
        
        if let sensitivity = message["sensitivity"] as? String {
            print("[WC] Received sensitivity update from Watch: \(sensitivity)")
            DispatchQueue.main.async {
                SensitivityDataModel.shared.applySyncUpdate(levelString: sensitivity)
            }
        }

        if let action = message["action"] as? String {
            print("[WC] Received action from Watch: \(action)")
            if action == "stopStream" {
                NotificationCenter.default.post(name: NSNotification.Name("StopHealthStream"), object: nil)
            } else if action == "startStream" {
                DispatchQueue.main.async { self.isWaitingForFirstSample = true }
                NotificationCenter.default.post(name: NSNotification.Name("StartHealthStream"), object: nil)
            } else if action == "triggerAlert" {
                print("[WC] Watch triggered emergency alert. Executing direct background logic.")
                executeEmergencyAlertFromWatch()
                NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredAlert"), object: nil)
            } else if action == "stopAlarm" {
                print("[WC] Received stopAlarm from Watch — silencing iPhone siren")
                DispatchQueue.main.async {
                    EmergencyAudioManager.shared.stopAlarm()
                    NotificationCenter.default.post(name: NSNotification.Name("StopEmergencySiren"), object: nil)
                }
            }
        }
    }

    // MARK: - Sensor Log Batches (Watch → iPhone)

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleSensorBatchData(messageData)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        // `transferUserInfo` supports Data values; we store the JSON under `sensor_batch`.
        if let data = userInfo["sensor_batch"] as? Data {
            handleSensorBatchData(data)
        }
    }
    
    private func handleSensorBatchData(_ data: Data) {
        do {
            let batch = try JSONDecoder().decode(WatchSensorBatchPayload.self, from: data)
            
            // Ensure we get enough background time to persist the batch even if the app is suspended.
            let bgTask = UIApplication.shared.beginBackgroundTask(withName: "sensorlog_ingest") {
                // No-op; we will end explicitly below.
            }
            
            Task {
                await SensorLogPipelineCoordinator.shared.ingestWatchBatch(batch)
                UIApplication.shared.endBackgroundTask(bgTask)
            }
        } catch {
            print("⚠️ [WC] Failed to decode sensor batch:", error.localizedDescription)
        }
    }
    
    private func executeEmergencyAlertFromWatch() {
        print("[WC] executeEmergencyAlertFromWatch: Initializing alert sequence")
        
        // 1. Get current location
        ensureLocationAuthorization()
        let location = locationManager.location
        if location == nil {
            print("⚠️ [WC] Location is nil. SOS might be sent with 0,0 or fail.")
        }
        
        // 2. Fetch contacts (MainActor.run because model is @MainActor)
        Task { @MainActor in
            let contacts = EmergencyContactDataModel.shared.getContactsForCurrentUser()
            print("[WC] Fetched \(contacts.count) contacts for Watch SOS")
            
            do {
                // Background trigger needs main-thread for consistent AudioSession activation
                await MainActor.run {
                    EmergencyAudioManager.shared.playEmergencyAlarm()
                }
                
                try await EmergencyService.shared.triggerEmergencyAlert(
                    latitude: location?.coordinate.latitude ?? 0.0,
                    longitude: location?.coordinate.longitude ?? 0.0,
                    contacts: contacts
                )
                print("✅ [WC] Global Emergency Alert successfully triggered from Watch signal")
            } catch {
                print("❌ [WC] Global Emergency Alert failed: \(error.localizedDescription)")
            }
        }
    }
}
