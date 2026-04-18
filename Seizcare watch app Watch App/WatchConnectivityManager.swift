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
    @Published var isStreaming: Bool = true
    
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
    }
    
    func stopStreaming() {
        print("[Watch] Requesting Stop Stream")
        WCSession.default.sendMessage(["action": "stopStream"], replyHandler: nil) { error in
            print("[Watch] Error sending stopStream: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            self.isStreaming = false
        }
    }
}
