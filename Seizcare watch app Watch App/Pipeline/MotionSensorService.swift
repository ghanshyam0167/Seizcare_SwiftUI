import Foundation
import CoreMotion
import Combine

/// Represents a single combined motion reading at a specific timestamp.
public struct MotionDataPoint {
    let timestamp: TimeInterval
    let accX: Double
    let accY: Double
    let accZ: Double
    let rotX: Double
    let rotY: Double
    let rotZ: Double
}

/// A service that abstracts CMMotionManager details and broadcasts stream.
public class MotionSensorService: ObservableObject {
    
    private let motionManager = CMMotionManager()
    private let sensorQueue = OperationQueue()
    
    // A callback or delegate is usually better for high-frequency data than @Published
    public var onNewDataPoint: ((MotionDataPoint) -> Void)?
    
    public init() {
        sensorQueue.qualityOfService = .userInteractive
    }
    
    public func startStreaming(updateInterval: TimeInterval = DetectionConfig.motionUpdateInterval) {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionSensorService] Device motion not available.")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: sensorQueue) { [weak self] data, error in
            guard let self = self, let dm = data, error == nil else { return }
            
            let point = MotionDataPoint(
                timestamp: dm.timestamp,
                accX: dm.userAcceleration.x,
                accY: dm.userAcceleration.y,
                accZ: dm.userAcceleration.z,
                rotX: dm.rotationRate.x,
                rotY: dm.rotationRate.y,
                rotZ: dm.rotationRate.z
            )
            
            self.onNewDataPoint?(point)
        }
    }
    
    public func stopStreaming() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}
