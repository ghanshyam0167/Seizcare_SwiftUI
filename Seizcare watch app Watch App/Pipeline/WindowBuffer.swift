import Foundation

/// A thread-safe, fixed-duration sliding window buffer for raw motion data.
public class WindowBuffer {
    
    private var data: [MotionDataPoint] = []
    private let queue = DispatchQueue(label: "com.seizcare.windowbuffer", attributes: .concurrent)
    
    public init() {}
    
    /// Adds a new data point to the buffer
    public func append(_ point: MotionDataPoint) {
        queue.async(flags: .barrier) {
            self.data.append(point)
            
            // Purge old data to keep memory usage bounds (e.g. keep max 60 seconds worth of data)
            let purgeThreshold = point.timestamp - 60.0
            if let firstValidIndex = self.data.firstIndex(where: { $0.timestamp >= purgeThreshold }) {
                if firstValidIndex > 0 {
                    self.data.removeFirst(firstValidIndex)
                }
            }
        }
    }
    
    /// Extracts a window of data for the last `seconds` duration. 
    /// Returns nil if there's insufficient duration in the buffer.
    public func fetchLatestWindow(seconds: TimeInterval) -> [MotionDataPoint]? {
        var result: [MotionDataPoint]?
        queue.sync {
            guard let last = data.last else { return }
            let cutoff = last.timestamp - seconds
            let windowData = data.filter { $0.timestamp >= cutoff }
            
            // Check if we roughly have enough samples
            let expectedSamples = Int(seconds / DetectionConfig.motionUpdateInterval)
            // Allow 80% tolerance because CoreMotion can drop frames occasionally
            if windowData.count >= Int(Double(expectedSamples) * 0.8) {
                result = windowData
            }
        }
        return result
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.data.removeAll()
        }
    }
}
