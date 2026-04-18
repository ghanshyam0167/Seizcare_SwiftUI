//
//  EmergencyAudioManager.swift
//  Seizcare
//

import Foundation
import AudioToolbox
import AVFoundation
import MediaPlayer

class EmergencyAudioManager {
    static let shared = EmergencyAudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let sirenFileName = "emergency_siren.wav"
    
    private init() {
        prepareSirenFile()
    }
    
    func playEmergencyAlarm() {
        print("[Audio] Playing reliable digital SOS siren")
        
        // 1. Maximize System Volume
        maximizeSystemVolume()
        
        // 2. Configure Audio Session to bypass Silent Switch
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Audio] Failed to set audio session: \(error.localizedDescription)")
        }
        
        // 3. Play the generated siren file
        let fileURL = getSirenFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.numberOfLoops = -1 // Loop infinitely
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                print("✅ [Audio] Siren playback started successfully")
            } catch {
                print("❌ [Audio] Failed to play siren file: \(error.localizedDescription)")
                // Fallback to system sound if player fails
                AudioServicesPlaySystemSound(1351)
            }
        } else {
            print("⚠️ [Audio] Siren file not found for playback")
            AudioServicesPlaySystemSound(1351)
        }
        
        // Haptic feedback as additional layer
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
    }
    
    func stopAlarm() {
        print("[Audio] Stopping alarm")
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func maximizeSystemVolume() {
        print("[Audio] Maximizing system volume...")
        let volumeView = MPVolumeView(frame: .zero)
        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            print("⚠️ [Audio] Could not find volume slider")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            slider.value = 1.0
        }
    }
    
    // MARK: - Siren Synthesis
    
    private func getSirenFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(sirenFileName)
    }
    
    private func prepareSirenFile() {
        let fileURL = getSirenFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL) // Overwrite with new sound
        }
        
        print("[Audio] Synthesizing iOS-style SOS siren WAV...")
        
        let sampleRate: Double = 44100.0
        let duration: Double = 4.0 // 4 seconds sequence
        let numSamples = Int(duration * sampleRate)
        
        var data = Data()
        addWavHeader(to: &data, sampleRate: Int32(sampleRate), numSamples: Int32(numSamples))
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            
            // Alternating Hi-Lo siren (1000Hz and 1500Hz) every 0.25 seconds
            let isHigh = (Int(t / 0.25) % 2 == 0)
            let freq = isHigh ? 1500.0 : 1000.0
            
            // Using a mix of sine and a bit of square-ish clipping for that sharp SOS sound
            let sine = sin(2.0 * .pi * freq * t)
            let sampleValue = Int16(sine * 32767.0)
            
            withUnsafeBytes(of: sampleValue.littleEndian) { data.append(contentsOf: $0) }
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ [Audio] Official-style SOS Siren synthesized")
        } catch {
            print("❌ [Audio] Failed to synthesize SOS siren: \(error.localizedDescription)")
        }
    }
    
    private func addWavHeader(to data: inout Data, sampleRate: Int32, numSamples: Int32) {
        let byteRate = sampleRate * 2 // 16-bit mono
        let totalDataSize = numSamples * 2
        
        data.append("RIFF".data(using: .ascii)!)
        withUnsafeBytes(of: (36 + totalDataSize).littleEndian) { data.append(contentsOf: $0) }
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        withUnsafeBytes(of: Int32(16).littleEndian) { data.append(contentsOf: $0) } // Subchunk1Size
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) } // AudioFormat (PCM)
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) } // NumChannels
        withUnsafeBytes(of: sampleRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(2).littleEndian) { data.append(contentsOf: $0) } // BlockAlign
        withUnsafeBytes(of: Int16(16).littleEndian) { data.append(contentsOf: $0) } // BitsPerSample
        data.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: totalDataSize.littleEndian) { data.append(contentsOf: $0) }
    }
}
