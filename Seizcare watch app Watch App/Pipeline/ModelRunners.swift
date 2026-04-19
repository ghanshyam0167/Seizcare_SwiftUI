import Foundation
import CoreML

public enum PipelineError: Error {
    case modelNotFound
    case dictFeatureProviderError
    case inferenceFailed
}

/// Executes the Artifact Filter to determine if the window is contaminated by motion artifacts.
public class ArtifactModelRunner {
    private var model: MLModel?
    
    public init() {
        loadModel()
    }
    
    private func loadModel() {
        // Dump all bundle resources so we can see what's available
        print("[ArtifactModelRunner] Bundle path: \(Bundle.main.bundlePath)")
        let allFiles = (try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath)) ?? []
        let modelFiles = allFiles.filter { $0.hasSuffix(".mlmodelc") || $0.hasSuffix(".mlmodel") }
        print("[ArtifactModelRunner] ML model files in bundle: \(modelFiles.isEmpty ? "NONE FOUND" : modelFiles.joined(separator: ", "))")
        
        // Try .mlmodelc first, then .mlmodel
        if let url = Bundle.main.url(forResource: "ArtifactFilter", withExtension: "mlmodelc") {
            print("[ArtifactModelRunner] Found ArtifactFilter.mlmodelc at: \(url)")
            loadFrom(url: url)
        } else if let url = Bundle.main.url(forResource: "ArtifactFilter", withExtension: "mlmodel") {
            print("[ArtifactModelRunner] Found ArtifactFilter.mlmodel at: \(url)")
            loadFrom(url: url)
        } else {
            print("[ArtifactModelRunner] ❌ ArtifactFilter model NOT found in bundle.")
            print("[ArtifactModelRunner] ⚠️  FIX: Select ArtifactFilter.mlmodel in Xcode → File Inspector → check 'Seizcare watch app Watch App' target.")
        }
    }
    
    private func loadFrom(url: URL) {
        do {
            model = try MLModel(contentsOf: url)
            print("[ArtifactModelRunner] ✅ Model loaded successfully.")
        } catch {
            print("[ArtifactModelRunner] ❌ Error loading model: \(error)")
        }
    }
    
    /// Returns the probability of the window being an artifact.
    public func predictArtifactProbability(features: [String: Any]) throws -> Double {
        guard let model = model else { throw PipelineError.modelNotFound }
        
        let provider: MLDictionaryFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            print("[ArtifactModelRunner] Invalid feature dictionary: \(error)")
            throw PipelineError.dictFeatureProviderError
        }
        
        do {
            let prediction = try model.prediction(from: provider)
            
            let label = prediction.featureValue(for: "activityLabel")?.stringValue ?? "unknown"
            let rawScores = prediction.featureValue(for: "activityScores")?.dictionaryValue as? [String: Double] ?? [:]
            
            // Convert raw logits → softmax probabilities
            let expScores = rawScores.mapValues { exp($0) }
            let expSum = expScores.values.reduce(0, +)
            let probs = expScores.mapValues { $0 / expSum }
            
            // "Artifacts" = daily activities that should suppress seizure detection
            let artifactClasses = ["walking", "workout", "stairs_motion"]
            let artifactProb = artifactClasses.compactMap { probs[$0] }.reduce(0, +)
            let restProb = probs["rest"] ?? 0.0
            
            print("[ArtifactModel] 🏃 Detected Activity: \(label.uppercased())")
            print("[ArtifactModel] 📊 Probabilities → rest: \(String(format: "%.1f%%", restProb * 100)) | walking: \(String(format: "%.1f%%", (probs["walking"] ?? 0) * 100)) | workout: \(String(format: "%.1f%%", (probs["workout"] ?? 0) * 100)) | stairs: \(String(format: "%.1f%%", (probs["stairs_motion"] ?? 0) * 100))")
            print("[ArtifactModel] 🎯 Artifact (non-rest activity) prob: \(String(format: "%.4f", artifactProb))")
            
            return artifactProb
        } catch {
            print("[ArtifactModelRunner] Inference failed: \(error)")
            throw PipelineError.inferenceFailed
        }
    }
}


/// Executes the Seizure Detection model to produce probability of seizure.
public class SeizureModelRunner {
    private var model: MLModel?
    
    public init() {
        loadModel()
    }
    
    private func loadModel() {
        print("[SeizureModelRunner] Bundle path: \(Bundle.main.bundlePath)")
        
        if let url = Bundle.main.url(forResource: "SeizureDetector", withExtension: "mlmodelc") {
            print("[SeizureModelRunner] Found SeizureDetector.mlmodelc at: \(url)")
            loadFrom(url: url)
        } else if let url = Bundle.main.url(forResource: "SeizureDetector", withExtension: "mlmodel") {
            print("[SeizureModelRunner] Found SeizureDetector.mlmodel at: \(url)")
            loadFrom(url: url)
        } else {
            print("[SeizureModelRunner] ❌ SeizureDetector model NOT found in bundle.")
            print("[SeizureModelRunner] ⚠️  FIX: Select SeizureDetector.mlmodel in Xcode → File Inspector → check 'Seizcare watch app Watch App' target.")
        }
    }
    
    private func loadFrom(url: URL) {
        do {
            model = try MLModel(contentsOf: url)
            print("[SeizureModelRunner] ✅ Model loaded successfully.")
        } catch {
            print("[SeizureModelRunner] ❌ Error loading model: \(error)")
        }
    }
    
    public func predictSeizure(features: [String: Any]) throws -> Double {
        guard let model = model else { throw PipelineError.modelNotFound }
        
        let provider: MLDictionaryFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            print("[SeizureModelRunner] Invalid feature dictionary: \(error)")
            throw PipelineError.dictFeatureProviderError
        }
        
        do {
            let prediction = try model.prediction(from: provider)
            
            if let probabilities = prediction.featureValue(for: "labelProbability")?.dictionaryValue as? [AnyHashable: Double] {
                let probSeizure = probabilities[Int64(1)] ?? probabilities["seizure"] ?? probabilities["Seizure"] ?? probabilities["Yes"] ?? 0.0
                return probSeizure
            }
            return 0.0
            
        } catch {
            print("[SeizureModelRunner] Inference failed: \(error)")
            throw PipelineError.inferenceFailed
        }
    }
}


