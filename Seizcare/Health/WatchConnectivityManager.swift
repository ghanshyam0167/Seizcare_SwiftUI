//
//  WatchConnectivityManager.swift
//  Seizcare
//

import Foundation
import WatchConnectivity
import CoreLocation
import Combine
import UserNotifications

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false
    @Published var isAppInstalled: Bool = false
    @Published var isStreaming: Bool = false
    @Published var isWaitingForFirstSample: Bool = false
    
    private var lastValidHeartRate: Double?
    private var lastUpdateTime: Date?
    private var lastAlertTriggerTime: Date?
    private var currentSeizureId: UUID?
    private var staleLogBucket: Int = -1
    private var streamTimer: AnyCancellable?

    /// Merged context dict — all keys (spo2, sleepHours, heartRate) live here together.
    /// updateApplicationContext REPLACES the whole dict, so we must send all keys every time.
    private var sharedContext: [String: Any] = [:]
    
    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?

    private override init() {
        super.init()
        
        // Setup Location for emergency triggers from Watch
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization() // Ensure we have permission
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            print("[WC] Session initialized on iOS")
        }
        
        streamTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.logHeartRateStalenessIfNeeded()
            }
    }

    private func logHeartRateStalenessIfNeeded() {
        guard let lastUpdateTime else {
            return
        }

        let age = Date().timeIntervalSince(lastUpdateTime)
        guard age >= 15 else {
            staleLogBucket = -1
            return
        }

        let bucket = Int(age / 15)
        guard bucket != staleLogBucket else {
            return
        }

        staleLogBucket = bucket
        print("[STREAM] Last update: \(lastUpdateTime)")
        print("[STREAM] Active: true")
        print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
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

    func sendForceTriggerToWatch() {
        print("[WC] Sending forceTrigger command to Watch")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "forceTrigger"], replyHandler: nil) { error in
                print("[ERROR] Failed to send forceTrigger to Watch: \(error.localizedDescription)")
            }
        }
    }

    func sendStopTaggingToWatch() {
        print("[WC] Sending stopTagging command to Watch")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "stopTagging"], replyHandler: nil) { error in
                print("[ERROR] Failed to send stopTagging to Watch: \(error.localizedDescription)")
            }
        }
    }

    func sendUserIdToWatch(_ id: String, token: String? = nil) {
        var msg: [String: Any] = ["userId": id]
        if let token = token {
            msg["accessToken"] = token
        }
        
        print("[WC] Syncing Auth to Watch (ID: \(id), Token: \(token != nil ? "YES" : "NO"))")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil) { error in
                print("[WC] Error sending Auth: \(error.localizedDescription)")
            }
        }
        pushContext(msg)
    }

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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("[IPHONE-WC] Received background userInfo from Watch: \(userInfo)")
        handleIncomingWatchData(userInfo, fromBackground: true)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WC] Received interactive message from Watch: \(message)")
        handleIncomingWatchData(message, fromBackground: false)
    }

    private func handleIncomingWatchData(_ message: [String: Any], fromBackground: Bool) {
        if let hr = message["heartRate"] as? Double {
            print("[WC] Direct HR from Watch: \(hr)")

            lastUpdateTime = Date()
            staleLogBucket = -1
            if hr > 0 {
                lastValidHeartRate = hr
            }
            DispatchQueue.main.async {
                self.isStreaming = true
                self.isWaitingForFirstSample = false
            }
            print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
            
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
                DispatchQueue.main.async {
                    self.isStreaming = false
                    self.isWaitingForFirstSample = false
                }
                NotificationCenter.default.post(name: NSNotification.Name("StopHealthStream"), object: nil)
            } else if action == "startStream" {
                DispatchQueue.main.async {
                    self.isStreaming = true
                    self.isWaitingForFirstSample = true
                }
                NotificationCenter.default.post(name: NSNotification.Name("StartHealthStream"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("StopEmergencySiren"), object: nil)
            }
        }
        
        // Standardized check for seizure_alert type from Watch (background/foreground)
        if let type = message["type"] as? String, type == "seizure_alert" {
            print("[IPHONE-WC] Standardized Seizure Alert payload received. Executing sequence.")
            let startTimeStr = message["startTime"] as? String
            let startTime = startTimeStr.flatMap { ISO8601DateFormatter().date(from: $0) }
            
            let sidStr = message["seizureId"] as? String
            let sid = sidStr.flatMap { UUID(uuidString: $0) }
            
            executeEmergencyAlertFromWatch(startTime: startTime, seizureId: sid)
            NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredAlert"), object: nil)
        }
        
        // Handle seizure_ended signal to close the duration "Measuring..." state
        if let type = message["type"] as? String, type == "seizure_ended" {
            let endTimeStr = message["endTime"] as? String
            let sidStr = message["seizureId"] as? String
            let sid = sidStr.flatMap { UUID(uuidString: $0) } ?? currentSeizureId
            
            if let endTime = endTimeStr.flatMap({ ISO8601DateFormatter().date(from: $0) }),
               let recordId = sid {
                print("[IPHONE-WC] Seizure ended signal received for record \(recordId). Updating.")
                Task {
                    await EmergencyService.shared.updateSeizureEndTime(recordId: recordId, endTime: endTime)
                    NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredAlert"), object: nil)
                }
            }
        }
        
        // Support legacy "triggerAlert" action for backward compatibility during transition
        if let action = message["action"] as? String, action == "triggerAlert" {
            print("[IPHONE-WC] Legacy triggerAlert action received. Executing sequence.")
            executeEmergencyAlertFromWatch()
            NotificationCenter.default.post(name: NSNotification.Name("WatchTriggeredAlert"), object: nil)
        }
    }
    
    private func triggerLocalEmergencyNotification() {
        print("[IPHONE-WC] Triggering local emergency notification...")
        let content = UNMutableNotificationContent()
        content.title = "🚨 Emergency Alert"
        content.body = "Possible seizure detected"
        
        // Debug: Check if alarm.caf is actually in the bundle
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "caf") {
            print("✅ [IPHONE-WC] Found alarm.caf in bundle at: \(soundURL.path)")
            content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.caf"))
        } else {
            print("❌ [IPHONE-WC] alarm.caf NOT found in bundle Resources! Using default sound.")
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: "EmergencyAlert-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [IPHONE-WC] Failed to trigger notification: \(error.localizedDescription)")
            } else {
                print("🔔 [IPHONE-WC] Notification successfully triggered with custom sound (alarm.caf)")
            }
        }
    }

    private func executeEmergencyAlertFromWatch(startTime: Date? = nil, seizureId: UUID? = nil) {
        // De-duplication: Ignore if we triggered an alert recently (e.g., within last 5 seconds)
        // Note: With unique session IDs, we can be more lenient, but still protect against rapid taps.
        if let lastTrigger = lastAlertTriggerTime, Date().timeIntervalSince(lastTrigger) < 5 {
            print("[IPHONE-WC] Alert ignored to prevent duplication (cooldown active)")
            return
        }
        
        lastAlertTriggerTime = Date()
        print("[WC] Alert received on iPhone. Initiating emergency sequence. StartTime: \(String(describing: startTime)), SeizureID: \(String(describing: seizureId))")
        
        // 1. Local UI/Audio feedback immediately
        triggerLocalEmergencyNotification()
        
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
                // Background trigger needs main-thread for consistent AudioSession activation
                await MainActor.run {
                    EmergencyAudioManager.shared.playEmergencyAlarm()
                }
                
                self.currentSeizureId = try await EmergencyService.shared.triggerEmergencyAlert(
                    latitude: location?.coordinate.latitude ?? 0.0,
                    longitude: location?.coordinate.longitude ?? 0.0,
                    startTime: startTime,
                    seizureId: seizureId,
                    contacts: contacts
                )
                print("✅ [WC] Global Emergency Alert successfully triggered from Watch signal. RecordId: \(String(describing: self.currentSeizureId))")
            } catch {
                print("❌ [WC] Global Emergency Alert failed: \(error.localizedDescription)")
            }
        }
    }
}
