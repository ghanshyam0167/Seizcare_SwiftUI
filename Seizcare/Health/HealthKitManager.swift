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
    private let oxygenSaturationType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
    
    private var hrQuery: HKAnchoredObjectQuery?
    private var observerQuery: HKObserverQuery?
    private var spo2ObserverQuery: HKObserverQuery?
    
    // Callback for heart rate updates — includes BPM value
    var heartRateUpdateHandler: ((Double) -> Void)?
    
    // Callback for heart rate timestamp — called alongside heartRateUpdateHandler
    var heartRateTimestampHandler: ((Date) -> Void)?
    
    // Callback for SpO2 updates
    var spo2UpdateHandler: ((Double) -> Void)?
    
    private init() {
        print("[HK] Initialized")
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HK] HealthKit not available on this device")
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [heartRateType, sleepAnalysisType, oxygenSaturationType]
        
        print("[HK] Requesting Auth for .heartRate, .sleepAnalysis, .oxygenSaturation")
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            let status = self.healthStore.authorizationStatus(for: self.heartRateType)
            print("[HK] Permission status: \(status.rawValue)")
            
            if success {
                print("[HK] Auth success: HealthKit access granted")
                
                // Enable background delivery for heart rate
                self.healthStore.enableBackgroundDelivery(for: self.heartRateType, frequency: .immediate) { success, error in
                    print("[HK] Background delivery setup — success=\(success), error=\(error?.localizedDescription ?? "none")")
                }
                
                // Log individual SpO2 status for debugging
                let spo2Status = self.healthStore.authorizationStatus(for: self.oxygenSaturationType)
                print("[HK] SpO2 auth status: \(spo2Status.rawValue) (0=notDetermined, 1=denied, 2=sharingAuthorized)")
            } else if let error = error {
                print("[ERROR] \(error.localizedDescription)")
            } else {
                print("[HK] Auth denied: User cancelled or restricted access")
            }
            completion(success, error)
        }
    }
    
    /// Call this explicitly to re-trigger the SpO2 permission dialog if it was skipped before.
    func requestSpO2Authorization(completion: @escaping (Bool) -> Void) {
        healthStore.requestAuthorization(toShare: nil, read: [oxygenSaturationType]) { success, error in
            let status = self.healthStore.authorizationStatus(for: self.oxygenSaturationType)
            print("[HK] SpO2-only auth — success=\(success), status=\(status.rawValue), error=\(error?.localizedDescription ?? "none")")
            completion(success)
        }
    }
    
    func startHeartRateStreaming() {
        if hrQuery != nil || observerQuery != nil {
            print("[HK] Streaming already active, skipping re-start")
            return
        }
        print("[HK] Starting HR Streaming (Observer + Anchored)")
        
        // 1. Observer Query for background updates (PRIMARY SOURCE)
        let observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            print("[HK] Observer triggered for heart rate update")
            if let error = error {
                print("[HK] Observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // FETCH LATEST VALUE (Step 2)
            self?.fetchLatestHeartRate { bpm, sampleDate in
                if let value = bpm {
                    print("[HK] HR fetched: \(value) BPM at \(sampleDate ?? Date())")
                }
                completionHandler() // MUST call this to let HK know we finished background work
            }
        }
        
        // Step 1.2: Enable background delivery (Frequency = .immediate)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            print("[HK] Background delivery setup — success=\(success), error=\(error?.localizedDescription ?? "none")")
        }
        
        healthStore.execute(observerQuery)
        self.observerQuery = observerQuery
        
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
        if let query = hrQuery {
            print("[HK] Stopping HR Anchored Query")
            healthStore.stop(query)
            self.hrQuery = nil
        }
        
        if let observer = observerQuery {
            print("[HK] Stopping HR Observer Query")
            healthStore.stop(observer)
            self.observerQuery = nil
        }
    }
    
    func startSpO2Streaming() {
        if spo2ObserverQuery != nil {
            print("[HK] SpO2 Streaming already active, skipping re-start")
            return
        }
        print("[HK] Starting SpO2 Streaming (Observer)")
        
        // Observer Query for background updates
        let observerQuery = HKObserverQuery(sampleType: oxygenSaturationType, predicate: nil) { [weak self] _, completionHandler, error in
            print("[HK] SpO2 Observer triggered")
            if error == nil {
                self?.fetchLatestSpO2 { spo2 in
                    if let spo2 = spo2 {
                        DispatchQueue.main.async {
                            self?.spo2UpdateHandler?(spo2)
                        }
                    }
                    completionHandler() // Let HK know we received it
                }
            } else {
                completionHandler()
            }
        }
        healthStore.execute(observerQuery)
        self.spo2ObserverQuery = observerQuery
    }
    
    func stopSpO2Streaming() {
        if let observer = spo2ObserverQuery {
            print("[HK] Stopping SpO2 Observer Query")
            healthStore.stop(observer)
            self.spo2ObserverQuery = nil
        }
    }
    
    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else {
            print("[HK] HR No data in batch")
            return
        }
        
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let sampleDate = latest.endDate
        print("[HK] HR Update: \(bpm) BPM, timestamp: \(sampleDate)")
        
        DispatchQueue.main.async {
            self.heartRateUpdateHandler?(bpm)
            self.heartRateTimestampHandler?(sampleDate)
        }
    }
    
    /// Fetches latest heart rate. Returns (bpm, sampleDate) so caller can check freshness.
    func fetchLatestHeartRate(completion: @escaping (Double?, Date?) -> Void) {
        print("[HK] Fetching heart rate...")
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("[ERROR] \(error.localizedDescription)")
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("[HK] No data available")
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            print("[HK] HR value: \(bpm)")
            let sampleDate = sample.endDate
            let age = Date().timeIntervalSince(sampleDate)
            print("[HK] HR latest: \(Int(bpm)) BPM, age: \(String(format: "%.0f", age))s, timestamp: \(sampleDate)")
            DispatchQueue.main.async {
                completion(bpm, sampleDate)
            }
        }
        healthStore.execute(query)
    }

    func fetchLatestSpO2(completion: @escaping (Double?) -> Void) {
        // Check auth status first — gives us a clear diagnostic
        let status = healthStore.authorizationStatus(for: oxygenSaturationType)
        print("[HK] Fetching latest SpO2... auth status=\(status.rawValue) (0=notDetermined, 1=sharingDenied, 2=sharingAuthorized)")
        
        // If not yet determined, request it now then query
        if status == .notDetermined {
            print("[HK] SpO2 auth not yet determined — requesting now")
            requestSpO2Authorization { _ in
                self.executeSpO2Query(completion: completion)
            }
        } else {
            executeSpO2Query(completion: completion)
        }
    }
    
    private func executeSpO2Query(completion: @escaping (Double?) -> Void) {
        print("[HK] Executing SpO2 HKSampleQuery...")
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: oxygenSaturationType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("[HK] SpO2 query error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            print("[HK] SpO2 query returned \(samples?.count ?? 0) sample(s)")
            guard let sample = samples?.first as? HKQuantitySample else {
                print("[HK] SpO2: No samples in HealthKit — have you taken an SpO2 reading on your Watch?")
                completion(nil)
                return
            }
            // HealthKit stores oxygenSaturation as a ratio (0.0–1.0)
            let rawValue = sample.quantity.doubleValue(for: HKUnit.percent())
            let percentage = rawValue * 100.0
            print("[HK] SpO2: raw=\(rawValue), display=\(Int(percentage))%, recorded=\(sample.endDate)")
            guard percentage > 50 && percentage <= 100 else {
                print("[HK] SpO2 value \(percentage) out of valid range — skipping")
                completion(nil)
                return
            }
            DispatchQueue.main.async {
                completion(percentage)
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
                    userId: nil,
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
    
    /// Fetches last night's sleep from Apple Watch only (yesterday 8 PM → today noon).
    /// Returns 0 if Apple Watch didn't record sleep — no fallback to iPhone or other sources.
    /// Merges overlapping stage segments (Core/Deep/REM) which Watch records as separate intervals.
    func fetchLastNightSleep(completion: @escaping (Double) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        
        // Window: yesterday 8 PM → today noon (max 16 hrs — one full night)
        guard
            let startOfToday = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
            let windowStart  = calendar.date(byAdding: .hour, value: -16, to: startOfToday),
            let windowEnd    = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)
        else {
            print("[HK] LastNightSleep: Could not build time window")
            completion(0)
            return
        }
        let effectiveEnd = now < windowEnd ? now : windowEnd
        print("[HK] LastNightSleep (Watch only) window: \(windowStart) → \(effectiveEnd)")
        
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: effectiveEnd, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: sleepAnalysisType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("[HK] LastNightSleep error: \(error.localizedDescription)")
                completion(0)
                return
            }
            let allSamples = (samples as? [HKCategorySample]) ?? []
            
            // Apple Watch only — filter by source name
            let watchSamples = allSamples.filter {
                $0.sourceRevision.source.name.lowercased().contains("watch")
            }
            print("[HK] LastNightSleep — total sources: \(Set(allSamples.map { $0.sourceRevision.source.name }))")
            print("[HK] Watch samples in window: \(watchSamples.count)")
            
            guard !watchSamples.isEmpty else {
                print("[HK] No Apple Watch sleep data found — showing 'No data'")
                DispatchQueue.main.async { completion(0) }
                return
            }
            
            // Filter only actual sleep stages (exclude inBed / awake)
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let sleepIntervals = watchSamples
                .filter { asleepValues.contains($0.value) }
                .map { ($0.startDate, $0.endDate) }
                .sorted { $0.0 < $1.0 }
            
            // Merge overlapping intervals — Watch records fine-grained stage segments
            // that can overlap (e.g. a Core segment overlapping with the next REM segment)
            var merged: [(Date, Date)] = []
            for interval in sleepIntervals {
                if let last = merged.last, interval.0 <= last.1 {
                    merged[merged.count - 1] = (last.0, max(last.1, interval.1))
                } else {
                    merged.append(interval)
                }
            }
            
            let totalSeconds = merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
            let hours = totalSeconds / 3600.0
            print("[HK] LastNightSleep (Watch): \(merged.count) merged intervals = \(String(format: "%.2f", hours)) hrs")
            DispatchQueue.main.async { completion(hours) }
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

    /// Debug Utility: Fetches sleep for last 30 days and prints ONE value per day.
    func printDailySleepHistory() {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: sleepAnalysisType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("[HK] Sleep History error: \(error.localizedDescription)")
                return
            }
            
            let allSamples = (samples as? [HKCategorySample]) ?? []
            if allSamples.isEmpty {
                print("No sleep data available")
                return
            }
            
            // 1. Filter for "asleep" only
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            
            // 2. Group by day and sum duration
            var dailySleep: [Date: Double] = [:]
            for sample in allSamples where asleepValues.contains(sample.value) {
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                let day = calendar.startOfDay(for: sample.startDate)
                dailySleep[day, default: 0] += duration
            }
            
            // 3. Print output
            let sortedDates = dailySleep.keys.sorted()
            if sortedDates.isEmpty {
                print("No sleep data available")
                return
            }
            
            print("----- Daily Sleep (One Value Per Day) -----")
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            for date in sortedDates {
                let hours = dailySleep[date] ?? 0
                if hours > 0 {
                    print("\(formatter.string(from: date)): \(String(format: "%.1f", hours)) hrs")
                }
            }
        }
        healthStore.execute(query)
    }
}
