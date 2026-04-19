import Foundation

/// Processes the stream of raw probabilities, applying voting and debounce logic to ensure high-confidence alerts.
public class DetectionDecisionEngine {
    
    private var recentPredictions: [Bool] = []
    private var lastAlertTime: Date = Date.distantPast
    
    public init() {}
    
    /// Feed a new probability. Returns true if the pipeline should trigger a confirmed seizure alarm.
    public func processProbability(_ probability: Double) -> Bool {
        let isPositive = probability >= DetectionConfig.seizureThreshold
        
        recentPredictions.append(isPositive)
        if recentPredictions.count > DetectionConfig.analysisWindowLimitForVoting {
            recentPredictions.removeFirst()
        }
        
        let positiveCount = recentPredictions.filter { $0 }.count
        
        // Check if we meet the voting threshold
        if positiveCount >= DetectionConfig.positiveWindowsRequiredForAlert {
            // Check cooldown
            if Date().timeIntervalSince(lastAlertTime) > DetectionConfig.postAlertCooldownSeconds {
                lastAlertTime = Date()
                // Reset queue to prevent immediate re-firing
                recentPredictions.removeAll()
                return true
            }
        }
        
        return false
    }
    
    public func reset() {
        recentPredictions.removeAll()
    }
}
