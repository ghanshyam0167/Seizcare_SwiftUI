//
//  HealthKitManager_Watch.swift
//  Seizcare watch app Watch App
//

import Foundation
import HealthKit
import Combine

class HealthKitManager_Watch: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = HealthKitManager_Watch()
    
    private let healthStore = HKHealthStore()
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    
    var heartRateUpdateHandler: ((Double) -> Void)?
    private var hrQuery: HKAnchoredObjectQuery?
    
    // Background Session management
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    override private init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Add Workout type to auth for background monitoring
        let typesToRead: Set<HKObjectType> = [heartRateType, HKObjectType.workoutType()]
        let typesToShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            let status = self.healthStore.authorizationStatus(for: self.heartRateType)
            print("[HK] Permission status: \(status.rawValue)")
            
            if success {
                print("[Watch-HK] Auth success — Starting streaming")
                self.startHeartRateStreaming()
            } else if let error = error {
                print("[ERROR] \(error.localizedDescription)")
            }
        }
    }
    
    func startHeartRateStreaming() {
        if workoutSession != nil {
            print("[Watch-HK] Background session already active, skipping re-start")
            return
        }
        
        print("[Watch-HK] Starting local HR Background Session")
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { success, error in
                if success {
                    print("[Watch-HK] Background collection started successfully")
                } else {
                    print("[Watch-HK] Background collection failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        } catch {
            print("[Watch-HK] Failed to create workout session: \(error.localizedDescription)")
            // Fallback to anchored query if session fails
            startAnchoredQuery()
        }
    }
    
    private func startAnchoredQuery() {
        print("[Watch-HK] Starting fallback anchored query")
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
        print("[Watch-HK] Stopping Background HR monitoring")
        
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            self.workoutSession = nil
            self.workoutBuilder = nil
        }
        
        if let query = hrQuery {
            healthStore.stop(query)
            self.hrQuery = nil
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("[Watch-HK] Session state changed to \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[ERROR] \(error.localizedDescription)")
        print("[Watch-HK] Session failed: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        if collectedTypes.contains(heartRateType) {
            guard let statistics = workoutBuilder.statistics(for: heartRateType),
                  let latest = statistics.mostRecentQuantity() else { 
                print("[HK] No data available")
                return 
            }
            
            let bpm = latest.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            print("[HK] HR value: \(bpm)")
            print("[Watch-HK] Background HR: \(Int(bpm)) BPM")
            
            DispatchQueue.main.async {
                self.heartRateUpdateHandler?(bpm)
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
    
    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }
        
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        print("[Watch-HK] Anchored HR: \(Int(bpm)) BPM")
        
        DispatchQueue.main.async {
            self.heartRateUpdateHandler?(bpm)
        }
    }
}
