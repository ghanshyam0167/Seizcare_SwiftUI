//
//  DemoDetectionManager.swift
//  Seizcare watch app Watch App
//

import Foundation
import CoreMotion
import Combine

enum DemoStatus: String {
    case monitoring = "Monitoring..."
    case highMovement = "High Movement Detected"
    case alertTriggered = "Seizure Alert (Demo)"
}

@MainActor
final class DemoDetectionManager: ObservableObject {
    static let shared = DemoDetectionManager()
    
    // Public state
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published private(set) var currentStatus: DemoStatus = .monitoring
    @Published private(set) var smoothedIntensity: Double = 0.0
    
    // Internal CoreMotion state
    private let motionManager = CMMotionManager()
    private var sampleWindow: [Double] = []
    private let maxSamples = 20
    private var timeAboveThreshold: Double = 0.0
    
    // Config
    private let threshold: Double = 2.5
    private let updateInterval: TimeInterval = 0.05 // 20Hz
    
    private init() {}
    
    func resetState() {
        self.timeAboveThreshold = 0.0
        self.currentStatus = .monitoring
    }
    
    private func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[Demo] Device motion not available")
            return
        }
        
        resetState()
        sampleWindow.removeAll()
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
        print("[Demo] Monitoring started at 20Hz")
    }
    
    private func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        resetState()
        smoothedIntensity = 0.0
        sampleWindow.removeAll()
        print("[Demo] Monitoring stopped")
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        guard currentStatus != .alertTriggered else { return }
        
        // Calculate magnitudes
        let accel = motion.userAcceleration
        let accelMag = sqrt(pow(accel.x, 2) + pow(accel.y, 2) + pow(accel.z, 2))
        
        let gyro = motion.rotationRate
        let gyroMag = sqrt(pow(gyro.x, 2) + pow(gyro.y, 2) + pow(gyro.z, 2))
        
        let intensity = accelMag + gyroMag
        
        // Moving average (last 20 samples = 1 second at 20Hz)
        sampleWindow.append(intensity)
        if sampleWindow.count > maxSamples {
            sampleWindow.removeFirst()
        }
        smoothedIntensity = sampleWindow.reduce(0, +) / Double(sampleWindow.count)
        
        // Detection Logic
        if smoothedIntensity > threshold {
            timeAboveThreshold += updateInterval
            
            if timeAboveThreshold >= 3.0 {
                currentStatus = .alertTriggered
            } else if timeAboveThreshold > 1.0 {
                currentStatus = .highMovement
            }
        } else {
            // Instant drop back to monitoring if below threshold
            timeAboveThreshold = 0.0
            currentStatus = .monitoring
        }
    }
}
