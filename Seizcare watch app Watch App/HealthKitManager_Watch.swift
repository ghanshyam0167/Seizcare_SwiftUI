//
//  HealthKitManager_Watch.swift
//  Seizcare watch app Watch App
//

import Foundation
import HealthKit
import Combine

class HealthKitManager_Watch: ObservableObject {
    static let shared = HealthKitManager_Watch()
    
    private let healthStore = HKHealthStore()
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    
    var heartRateUpdateHandler: ((Double) -> Void)?
    private var hrQuery: HKAnchoredObjectQuery?
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, error in
            if success {
                self.startHeartRateStreaming()
            }
        }
    }
    
    func startHeartRateStreaming() {
        if hrQuery != nil {
            print("[Watch-HK] Streaming already active, skipping re-start")
            return
        }
        print("[Watch-HK] Starting local HR Streaming")
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.processHRSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.processHRSamples(samples)
        }
        
        healthStore.execute(query)
        self.hrQuery = query
    }
    
    func stopHeartRateStreaming() {
        guard let query = hrQuery else {
            print("[Watch-HK] No local HR Query to stop")
            return
        }
        print("[Watch-HK] Stopping local HR Streaming")
        healthStore.stop(query)
        self.hrQuery = nil
    }
    
    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        print("[Watch-HK] Local HR: \(Int(bpm)) BPM")
        
        DispatchQueue.main.async {
            self.heartRateUpdateHandler?(bpm)
        }
    }
}
