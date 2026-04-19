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
    }
    
    private func sendLocalHRtoPhone(_ bpm: Double) {
        guard isStreaming else {
            return
        }
        
        print("[Watch] Sending local HR to Phone: \(bpm)")
        DispatchQueue.main.async { self.heartRate = bpm }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["heartRate": bpm], replyHandler: nil) { error in
                print("[Watch] Error sending local HR: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[Watch] WCSession activated: \(activationState.rawValue)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("[Watch] Message received: \(message)")
        
        DispatchQueue.main.async {
            if let hr = message["heartRate"] as? Double {
                self.heartRate = hr
                print("[Watch] Received HR: \(hr)")
            }
            
            if let sleep = message["sleepHours"] as? Double {
                self.sleepHours = sleep
                print("[Watch] Received Sleep: \(sleep)")
            }
            
            if let spo2 = message["spo2"] as? Double {
                self.spo2 = spo2
                print("[Watch] Received SpO2: \(spo2)")
            }
            
            if let levelString = message["sensitivity"] as? String {
                self.sensitivity = self.mapSensitivityStringToInt(levelString)
                print("[Watch] Received sensitivity: \(levelString) (\(self.sensitivity))")
            }
        }
    }
    
    // Fallback: values sent via updateApplicationContext arrive here
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("[Watch] Received applicationContext: \(applicationContext)")
        DispatchQueue.main.async {
            if let spo2 = applicationContext["spo2"] as? Double {
                self.spo2 = spo2
                print("[Watch] SpO2 from context: \(spo2)")
            }
            if let hr = applicationContext["heartRate"] as? Double {
                self.heartRate = hr
            }
            if let sleep = applicationContext["sleepHours"] as? Double {
                self.sleepHours = sleep
            }
            if let levelString = applicationContext["sensitivity"] as? String {
                self.sensitivity = self.mapSensitivityStringToInt(levelString)
                print("[Watch] Context sensitivity: \(levelString)")
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
        print("[Watch-SOS] Sending alert trigger to iPhone")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "triggerAlert"], replyHandler: nil) { error in
                print("[Watch-SOS] Error sending alert trigger: \(error.localizedDescription)")
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
