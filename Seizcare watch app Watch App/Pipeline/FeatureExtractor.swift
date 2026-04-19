import Foundation

/// Takes a window of motion data and heart rate, outputs features required by our models
public class FeatureExtractor {

    /// Calculate basic statistics for an array of doubles
    private static func computeStats(_ values: [Double]) -> (mean: Double, std: Double, min: Double, max: Double, range: Double) {
        guard !values.isEmpty else { return (0, 0, 0, 0, 0) }
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let sumOfSquaredDifferences = squaredDifferences.reduce(0, +)
        let std = sqrt(sumOfSquaredDifferences / count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        return (mean, std, minVal, maxVal, maxVal - minVal)
    }
    
    /// Calculate zero crossings around mean
    private static func computeZeroCrossings(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        var crossings = 0
        for i in 1..<values.count {
            if (values[i-1] - mean) * (values[i] - mean) < 0 { crossings += 1 }
        }
        return Double(crossings)
    }

    /// Extracts dictionary of features for the ArtifactFilter.mlmodel
    public static func extractArtifactFeatures(window: [MotionDataPoint]) -> [String: Any]? {
        guard !window.isEmpty else { return nil }
        
        let accX = window.map { $0.accX }
        let accY = window.map { $0.accY }
        let accZ = window.map { $0.accZ }
        let mags = window.map { point -> Double in
            let ax = point.accX * point.accX
            let ay = point.accY * point.accY
            let az = point.accZ * point.accZ
            return sqrt(ax + ay + az)
        }
        
        let statsX = computeStats(accX)
        let statsY = computeStats(accY)
        let statsZ = computeStats(accZ)
        let statsMag = computeStats(mags)
        
        // Jerk approximation (diff of consecutive magnitudes)
        var jerks: [Double] = []
        for i in 1..<mags.count {
            let dt = window[i].timestamp - window[i-1].timestamp
            let jerk = dt > 0 ? abs(mags[i] - mags[i-1]) / dt : 0
            jerks.append(jerk)
        }
        let statsJerk = computeStats(jerks)
        let jerkSquared = jerks.map { $0 * $0 }
        let jerkSumSquared = jerkSquared.reduce(0, +)
        let jerkRms = sqrt(jerkSumSquared / Double(max(1, jerks.count)))
        
        let magsSquared = mags.map { $0 * $0 }
        let magsSumSquared = magsSquared.reduce(0, +)
        let rmsMag = sqrt(magsSumSquared / Double(max(1, mags.count)))
        
        let absX = accX.map { abs($0) }
        let absY = accY.map { abs($0) }
        let absZ = accZ.map { abs($0) }
        let sumAbs = absX.reduce(0, +) + absY.reduce(0, +) + absZ.reduce(0, +)
        let sma = sumAbs / Double(max(1, window.count))
        
        let squaredMags = mags.map { pow($0, 2) }
        let energy = squaredMags.reduce(0, +)
        
        // Dominant frequency approximation (Mock implementation: FFT requires external library or accelerate framework; 0.0 for safety or simple peak counting)
        // TODO: Implement actual vDSP FFT for acc_dom_freq if required by model, defaulting to 0 for simplicity.
        let domFreq = 0.0 
        
        let zcX = computeZeroCrossings(accX, mean: statsX.mean)
        let zcY = computeZeroCrossings(accY, mean: statsY.mean)
        let zcZ = computeZeroCrossings(accZ, mean: statsZ.mean)

        var features: [String: Any] = [:]
        features["acc_mean_x"] = statsX.mean
        features["acc_mean_y"] = statsY.mean
        features["acc_mean_z"] = statsZ.mean
        features["acc_std_x"] = statsX.std
        features["acc_std_y"] = statsY.std
        features["acc_std_z"] = statsZ.std
        features["acc_min_x"] = statsX.min
        features["acc_min_y"] = statsY.min
        features["acc_min_z"] = statsZ.min
        features["acc_max_x"] = statsX.max
        features["acc_max_y"] = statsY.max
        features["acc_max_z"] = statsZ.max
        features["acc_range_x"] = statsX.range
        features["acc_range_y"] = statsY.range
        features["acc_range_z"] = statsZ.range
        features["acc_mean_mag"] = statsMag.mean
        features["acc_std_mag"] = statsMag.std
        features["acc_min_mag"] = statsMag.min
        features["acc_max_mag"] = statsMag.max
        features["acc_rms_mag"] = rmsMag
        features["acc_sma"] = sma
        features["acc_energy"] = energy
        features["acc_dom_freq"] = domFreq
        features["acc_zc_x"] = zcX
        features["acc_zc_y"] = zcY
        features["acc_zc_z"] = zcZ
        features["jerk_mean"] = statsJerk.mean
        features["jerk_std"] = statsJerk.std
        features["jerk_rms"] = jerkRms
        features["samples_in_window"] = Double(window.count)
        return features
    }

    /// Extracts dictionary of features for the SeizureDetector.mlmodel
    public static func extractSeizureFeatures(window: [MotionDataPoint], hrValue: Double, isArtifact: Bool, isNonwear: Bool) -> [String: Any]? {
        guard !window.isEmpty else { return nil }
        
        let mags = window.map { point -> Double in
            let ax = point.accX * point.accX
            let ay = point.accY * point.accY
            let az = point.accZ * point.accZ
            return sqrt(ax + ay + az)
        }
        let statsMag = computeStats(mags)
        
        var jerks: [Double] = []
        for i in 1..<mags.count {
            let dt = max(0.01, window[i].timestamp - window[i-1].timestamp)
            jerks.append(abs(mags[i] - mags[i-1]) / dt)
        }
        let jerkMean = computeStats(jerks).mean
        let domFreq = 0.0 // See note above regarding FFT
        
        // Note: SeizureDetector requires 1-hot encoded seizure_type which we do not have in live inference.
        // We set seizure_type to `none` (default condition) or 0s as per the safety fallback rules.
        // It also requires EDA, BVP, and Temp which are not natively available on watchOS, supplying 0 fallbacks explicitly.
        var features: [String: Any] = [:]
        features["artifact_flag"] = isArtifact ? 1.0 : 0.0
        features["nonwear_flag"] = isNonwear ? 1.0 : 0.0
        features["acc_mag_mean"] = statsMag.mean
        features["acc_mag_std"] = statsMag.std
        features["acc_dominant_freq_hz"] = domFreq
        features["jerk_mean"] = jerkMean
        features["hr_mean"] = hrValue
        features["hr_delta_30s"] = 0.0
        features["rmssd_ms"] = 0.0
        
        // Missing Apple Watch Sensors: Fallbacks
        features["bvp_amp"] = 0.0
        features["bvp_noise_ratio"] = 0.0
        features["signal_quality"] = 1.0
        features["eda_tonic_us"] = 0.0
        features["eda_phasic_us"] = 0.0
        features["eda_slope"] = 0.0
        features["temp_c"] = 36.5
        features["temp_slope"] = 0.0
        
        // One-Hot Encoded Training Fields: Fallback to 0.
        features["seizure_type__fbtc_gtc"] = 0.0
        features["seizure_type__focal_impaired_awareness"] = 0.0
        features["seizure_type__focal_motor"] = 0.0
        features["seizure_type__none"] = 1.0
        features["seizure_type__tonic"] = 0.0
        features["seizure_type__unknown"] = 0.0
        
        return features
    }
}
