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
    @Published var sensitivity: Int = 1 // 0: low, 1: medium, 2: high
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("[Watch] WCSession initiated")
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
                print("[Watch] Received SpO2 via message: \(spo2)")
            }
            
            if let levelString = message["sensitivity"] as? String {
                self.sensitivity = self.mapSensitivityStringToInt(levelString)
                print("[Watch] Received sensitivity: \(levelString) (\(self.sensitivity))")
            }
        }
    }
    
    // Fallback: catch values sent via updateApplicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("[Watch] Received applicationContext: \(applicationContext)")
        DispatchQueue.main.async {
            if let spo2 = applicationContext["spo2"] as? Double {
                self.spo2 = spo2
                print("[Watch] Received SpO2 via context: \(spo2)")
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
    
    func triggerEmergencyAlert() {
        print("[Watch-SOS] Sending alert trigger to iPhone")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["action": "triggerAlert"], replyHandler: nil) { error in
                print("[Watch-SOS] Error sending alert trigger: \(error.localizedDescription)")
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
    
    private func mapSensitivityIntToString(_ value: Int) -> String {
        switch value {
        case 0: return "low"
        case 2: return "high"
        default: return "medium"
        }
    }
}
