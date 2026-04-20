import Foundation
import Combine

public enum PipelineState {
    case stopped
    case running
    case artifactSuppression
    case seizureDetected
}

/// The facade manager linking CoreMotion, HealthKit, Buffer, Extractor, Models, and Engine.
public class DetectionPipelineManager: ObservableObject {
    
    private let motionService = MotionSensorService()
    private let hrService = HealthKitService.shared
    
    private let buffer = WindowBuffer()
    private let artifactRunner = ArtifactModelRunner()
    private let seizureRunner = SeizureModelRunner()
    private let decisionEngine = DetectionDecisionEngine()
    
    // Publishers for UI integration
    @Published public var state: PipelineState = .stopped
    @Published public var currentBufferCount: Int = 0
    @Published public var lastArtifactProbability: Double = 0.0
    @Published public var lastSeizureProbability: Double = 0.0
    @Published public var debugLog: String = "Pipeline initialized."
    
    // DEMO OVERRIDE SYSTEM
    public var demoMode: Bool = true
    public var forceSeizureTrigger: Bool = false
    
    private var pipelineTimer: Timer?
    
    public init() {
        motionService.onNewDataPoint = { [weak self] point in
            self?.buffer.append(point)
        }
    }
    
    public func start() {
        log("Requesting permissions...")
        hrService.requestPermissions { [weak self] success in
            guard let self = self else { return }
            self.log("HealthKit Permissions: \(success)")
            self.hrService.startStreamingHeartRate()
            self.motionService.startStreaming()
            self.decisionEngine.reset()
            self.buffer.clear()
            self.state = .running
            
            // We run the pipeline assessment loop manually every `windowOverlapSeconds`
            self.pipelineTimer = Timer.scheduledTimer(withTimeInterval: DetectionConfig.windowOverlapSeconds, repeats: true) { _ in
                self.runEvaluationLoop()
            }
            // Execute once immediately
            self.runEvaluationLoop()
        }
    }
    
    public func stop() {
        motionService.stopStreaming()
        hrService.stopStreaming()
        pipelineTimer?.invalidate()
        pipelineTimer = nil
        state = .stopped
        log("Pipeline stopped.")
    }
    
    private func runEvaluationLoop() {
        // 1 & 2. Fetch Buffered Data
        guard let window = buffer.fetchLatestWindow(seconds: DetectionConfig.windowSizeSeconds) else {
            print("[Pipeline] ⏳ Buffer filling... (need \(DetectionConfig.windowSizeSeconds)s of data)")
            DispatchQueue.main.async { [weak self] in
                self?.currentBufferCount = 0
            }
            return
        }
        
        print("[Pipeline] ✅ Window ready: \(window.count) samples — running inference...")
        DispatchQueue.main.async { [weak self] in
            self?.currentBufferCount = window.count
        }
        
        // Run ML Inference on a background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.executeInference(window: window)
        }
    }
    
    private func executeInference(window: [MotionDataPoint]) {
        // 3. Feature Extraction for Artifact
        guard let artifactFeatures = FeatureExtractor.extractArtifactFeatures(window: window) else {
            print("[Pipeline] ❌ Feature extraction failed for artifact model.")
            return
        }
        
        do {
            // 4. Artifact Model Inference
            let artifactProb = try artifactRunner.predictArtifactProbability(features: artifactFeatures)
            
            // DEMO OVERRIDE CHECK
            let hr = hrService.currentHeartRate
            if demoMode && forceSeizureTrigger {
                print("[DEMO] 🚨 Pipeline Bypass Triggered!")
                DispatchQueue.main.async { [weak self] in
                    self?.forceSeizureTrigger = false // Reset trigger
                    self?.state = .seizureDetected
                    self?.log("[DEMO] 🚨 SEIZURE FORCED")
                }
                
                // Trigger WatchConnectivity to notify iOS about the demo seizure
                WatchConnectivityManager.shared.sendDemoTrigger(hr: hr)
                return
            }
            
            let isArtifact = artifactProb >= DetectionConfig.artifactThreshold
            if isArtifact {
                print("[Pipeline] 🔶 ARTIFACT GATED — Motion artifact suppressing seizure check (prob: \(String(format: "%.3f", artifactProb)))")
                DispatchQueue.main.async { [weak self] in
                    self?.lastArtifactProbability = artifactProb
                    self?.state = .artifactSuppression
                    self?.log("Gated: Artifact Detected (prob: \(String(format: "%.2f", artifactProb)))")
                }
                _ = decisionEngine.processProbability(0.0) // Reset smoothing
                return // Suppress detection
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.lastArtifactProbability = artifactProb
            }
            
            // 5. Feature Extraction for Seizure Model
            guard let seizureFeatures = FeatureExtractor.extractSeizureFeatures(window: window, hrValue: hr, isArtifact: isArtifact, isNonwear: false) else {
                print("[Pipeline] ❌ Feature extraction failed for seizure model.")
                return
            }
            
            // Run Seizure Model Inference
            let seizureProb = try seizureRunner.predictSeizure(features: seizureFeatures)
            
            print("[Pipeline] 🧠 Seizure prob: \(String(format: "%.4f", seizureProb)) | Artifact prob: \(String(format: "%.4f", artifactProb)) | HR: \(Int(hr)) BPM")
            
            DispatchQueue.main.async { [weak self] in
                self?.lastSeizureProbability = seizureProb
                self?.state = .running
                self?.log("Seizure Prob: \(String(format: "%.4f", seizureProb)) | HR: \(Int(hr))")
            }
            
            // 6. Decision Logic Smoothing
            let confirmedDetection = decisionEngine.processProbability(seizureProb)
            if confirmedDetection {
                print("[Pipeline] 🚨🚨🚨 SEIZURE CONFIRMED — Alarm triggered!")
                DispatchQueue.main.async { [weak self] in
                    self?.state = .seizureDetected
                    self?.log("🚨 SEIZURE DETECTED! Alarm Confirmed.")
                }
            }
            
        } catch {
            print("[Pipeline] ❌ Inference Error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.log("Inference Error: \(error)")
            }
        }
    }
    
    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: Date())
        
        self.debugLog = "[\(timeString)] \(message)\n" + self.debugLog
        
        // Keep log short
        let lines = self.debugLog.split(separator: "\n")
        if lines.count > 10 {
            self.debugLog = lines.prefix(10).joined(separator: "\n")
        }
    }
}
