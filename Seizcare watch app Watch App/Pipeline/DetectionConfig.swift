import Foundation

/// Configuration defaults for the 7-stage Seizure Detection Pipeline
public struct DetectionConfig {
    
    // Sensor Rates
    public static let motionUpdateInterval: TimeInterval = 1.0 / 50.0 // 50 Hz
    
    // Buffering
    public static let windowSizeSeconds: Double = 5.0
    public static let windowOverlapSeconds: Double = 1.0 // Advance window by 1 second
    
    public static var requiredMotionSamplesPerWindow: Int {
        return Int(windowSizeSeconds / motionUpdateInterval)
    }
    
    // Artifact Filtering model thresholds
    public static let artifactThreshold: Double = 0.6 // Probability above which we drop window
    
    // Seizure Detection threshold
    public static let seizureThreshold: Double = 0.8 // Probability above which we trigger logic
    
    // Decision Engine smoothing
    public static let positiveWindowsRequiredForAlert = 3
    public static let analysisWindowLimitForVoting = 5 // Out of the last 5 windows
    
    // Cooldown logic
    public static let postAlertCooldownSeconds: TimeInterval = 30.0
    
    // Shake-to-Detect (Demo/Simulated Seizure)
    public static let shakeThresholdG: Double = 2.4 // Above 2g is quite vigorous
    public static let shakeWindowSeconds: TimeInterval = 10.0
    public static let requiredShakePeaks: Int = 25 // ~2.5 peaks per second for 10s
    public static let shakeCooldownSeconds: TimeInterval = 30.0
}
