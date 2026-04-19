import Foundation
import HealthKit
import Combine

/// Provides simple access to live streaming heart rate and recent RMSSD (if available).
public class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    private var hrQuery: HKQuery?
    
    @Published public var currentHeartRate: Double = 0.0
    @Published public var isAuthorized: Bool = false
    
    public init() {}
    
    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let rmssdType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)! // SDNN proxy if rmssd isn't available
        
        let typesToRead: Set<HKObjectType> = [hrType, rmssdType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success)
            }
        }
    }
    
    public func startStreamingHeartRate() {
        guard isAuthorized else { return }
        
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.process(samples: samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            self?.process(samples: samples)
        }
        
        self.hrQuery = query
        healthStore.execute(query)
    }
    
    public func stopStreaming() {
        if let query = hrQuery {
            healthStore.stop(query)
            hrQuery = nil
        }
    }
    
    private func process(samples: [HKSample]?) {
        guard let hrSamples = samples as? [HKQuantitySample], let last = hrSamples.last else { return }
        
        let hrValue = last.quantity.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async {
            self.currentHeartRate = hrValue
        }
    }
}
