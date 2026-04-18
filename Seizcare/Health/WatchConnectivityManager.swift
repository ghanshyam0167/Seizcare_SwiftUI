//
//  WatchConnectivityManager.swift
//  Seizcare
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("[WC] Session initialized on iOS")
        }
    }
    
    // MARK: - API
    
    func sendHeartRateToWatch(_ value: Double) {
        guard WCSession.default.activationState == .activated else {
            print("[WC] Cannot send HR: Session not activated")
            return
        }
        
        if WCSession.default.isReachable {
            let message = ["heartRate": value]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[WC] Error sending HR: \(error.localizedDescription)")
            }
            print("[WC] Sent HR: \(value)")
        } else {
            print("[WC] Not reachable for HR")
        }
    }
    
    func sendSleepDataToWatch(_ sleep: Double) {
        guard WCSession.default.activationState == .activated else {
            print("[WC] Cannot send Sleep: Session not activated")
            return
        }
        
        if WCSession.default.isReachable {
            let message = ["sleepHours": sleep]
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[WC] Error sending Sleep: \(error.localizedDescription)")
            }
            print("[WC] Sent Sleep: \(sleep)")
        } else {
            print("[WC] Not reachable for Sleep")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WC] Session activated on iOS: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WC] Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("[WC] Session deactivated. Re-activating...")
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("[WC] Received message from Watch: \(message)")
        
        if let hr = message["heartRate"] as? Double {
            print("[WC] Direct HR from Watch: \(hr)")
            NotificationCenter.default.post(name: NSNotification.Name("WatchHeartRateUpdate"), object: nil, userInfo: ["bpm": hr])
        }
        
        if let action = message["action"] as? String {
            print("[WC] Received action from Watch: \(action)")
            if action == "stopStream" {
                NotificationCenter.default.post(name: NSNotification.Name("StopHealthStream"), object: nil)
            } else if action == "startStream" {
                NotificationCenter.default.post(name: NSNotification.Name("StartHealthStream"), object: nil)
            }
        }
    }
}
