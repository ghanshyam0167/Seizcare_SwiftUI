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
    @Published var sleepHours: Double = 0
    
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
        }
    }
}
