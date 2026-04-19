//
//  WatchConnectivityManager.swift
//  Seizcare
//

import Foundation
import WatchConnectivity
import CoreLocation

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    /// Merged context dict — all keys (spo2, sleepHours, heartRate) live here together.
    /// updateApplicationContext REPLACES the whole dict, so we must send all keys every time.
    private var sharedContext: [String: Any] = [:]
    
    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?

    private override init() {
        super.init()
        
        // Setup Location for emergency triggers from Watch
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization() // Ensure we have permission
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            print("[WC] Session initialized on iOS")
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
            print("[WC] Context push error: \(error.localizedDescription)")
        }
    }

    // MARK: - API

    func sendHeartRateToWatch(_ value: Double) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["heartRate": value], replyHandler: nil) { error in
                print("[WC] Error sending HR: \(error.localizedDescription)")
            }
            print("[WC] Sent HR live: \(value)")
        }
        pushContext(["heartRate": value])
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
        print("[WC] Session activated on iOS: \(activationState.rawValue)")
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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WC] Received message from Watch: \(message)")

        if let hr = message["heartRate"] as? Double {
            print("[WC] Direct HR from Watch: \(hr)")
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
                NotificationCenter.default.post(name: NSNotification.Name("StartHealthStream"), object: nil)
            } else if action == "triggerAlert" {
                print("[WC] Watch triggered emergency alert. Executing direct background logic.")
                executeEmergencyAlertFromWatch()
                NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredAlert"), object: nil)
            }
        }
    }
    
    private func executeEmergencyAlertFromWatch() {
        print("[WC] executeEmergencyAlertFromWatch: Initializing alert sequence")
        
        // 1. Get current location
        let location = locationManager.location
        if location == nil {
            print("⚠️ [WC] Location is nil. SOS might be sent with 0,0 or fail.")
        }
        
        // 2. Fetch contacts (MainActor.run because model is @MainActor)
        Task { @MainActor in
            let contacts = EmergencyContactDataModel.shared.getContactsForCurrentUser()
            print("[WC] Fetched \(contacts.count) contacts for Watch SOS")
            
            do {
                // Countdown finished on Watch! Trigger SIREN on iPhone immediately
                EmergencyAudioManager.shared.playEmergencyAlarm()
                
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
