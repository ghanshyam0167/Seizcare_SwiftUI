//
//  HealthKitManager.swift
//  Seizcare
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let sleepAnalysisType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    private var hrQuery: HKAnchoredObjectQuery?
    
    // Callback for heart rate updates
    var heartRateUpdateHandler: ((Double) -> Void)?
    
    private init() {
        print("[HK] Initialized")
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HK] HealthKit not available on this device")
            completion(false, nil)
            return
        }
        
        let typesToRead: Set = [heartRateType, sleepAnalysisType]
        
        print("[HK] Requesting Auth for .heartRate and .sleepAnalysis")
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("[HK] Auth success: HealthKit access granted")
            } else if let error = error {
                print("[HK] Auth failed ERROR: \(error.localizedDescription)")
            } else {
                print("[HK] Auth denied: User cancelled or restricted access")
            }
            completion(success, error)
        }
    }
    
    func startHeartRateStreaming() {
        print("[HK] Starting HR Streaming (Observer + Anchored)")
        
        // 1. Observer Query for background updates
        let observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            print("[HK] HR Observer triggered")
            if error == nil {
                self?.fetchLatestHeartRate { bpm in
                    completionHandler() // Let HK know we received it
                }
            } else {
                completionHandler()
            }
        }
        healthStore.execute(observerQuery)
        
        // 2. Anchored Query for detailed sequence
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
            print("[HK] No HR Query to stop")
            return
        }
        print("[HK] Stopping HR Streaming")
        healthStore.stop(query)
        self.hrQuery = nil
    }
    
    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else {
            print("[HK] HR No data in batch")
            return
        }
        
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        print("[HK] HR Update: \(bpm) BPM")
        
        DispatchQueue.main.async {
            self.heartRateUpdateHandler?(bpm)
        }
    }
    
    func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        print("[HK] Fetching latest HR...")
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                print("[HK] HR latest: No data")
                completion(nil)
                return
            }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            print("[HK] HR latest found: \(Int(bpm)) BPM")
            DispatchQueue.main.async {
                completion(bpm)
            }
        }
        healthStore.execute(query)
    }

    func fetchHeartRateSamples(from start: Date, to end: Date, completion: @escaping ([HeartRateSample]) -> Void) {
        print("[HK] Fetching HR samples from: \(start) to: \(end)")
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let samples = samples as? [HKQuantitySample] else {
                print("[HK] HR range: No data or error")
                completion([])
                return
            }
            
            let result = samples.map { sample in
                HeartRateSample(
                    id: UUID(),
                    timestamp: sample.startDate,
                    bpm: Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min"))),
                    recordId: nil
                )
            }
            print("[HK] HR range processed: \(result.count) samples")
            completion(result)
        }
        healthStore.execute(query)
    }
    
    func fetchTodaySleep(completion: @escaping (Double) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        print("[HK] Fetching Sleep data for today (since \(startOfToday))")
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfToday, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepAnalysisType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                print("[HK] Sleep Today: No data or error")
                completion(0)
                return
            }
            
            var totalDuration: Double = 0
            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    
                    totalDuration += sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                }
            }
            
            print("[HK] Sleep Today: \(totalDuration) hours")
            completion(totalDuration)
        }
        
        healthStore.execute(query)
    }
    
    func fetchSleepData(lastDays: Int, completion: @escaping ([SleepData]) -> Void) {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -lastDays, to: endDate) else {
            print("[HK] Sleep: Could not calculate start date")
            completion([])
            return
        }
        
        print("[HK] Fetching Sleep data for last \(lastDays) days (from \(startDate) to \(endDate))")
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: sleepAnalysisType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                print("[HK] Sleep: No data or error \(error?.localizedDescription ?? "")")
                completion([])
                return
            }
            
            print("[HK] Sleep raw samples: \(samples.count)")
            
            // Group sleep samples by day
            let calendar = Calendar.current
            var sleepByDate: [Date: Double] = [:]
            
            for sample in samples {
                // Only consider "asleep" periods
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    let day = calendar.startOfDay(for: sample.startDate)
                    sleepByDate[day, default: 0] += duration
                }
            }
            
            let result = sleepByDate.map { SleepData(date: $0.key, duration: $0.value) }
                .sorted { $0.date > $1.date }
            
            print("[HK] Sleep processed: \(result.count) days")
            completion(result)
        }
        
        healthStore.execute(query)
    }
}
