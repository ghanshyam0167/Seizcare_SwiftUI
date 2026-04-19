//
//  EmergencyAudioManager.swift
//  Seizcare
//

import Foundation
import AudioToolbox
import AVFoundation
import MediaPlayer
import UserNotifications

class EmergencyAudioManager {
    static let shared = EmergencyAudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let sirenFileName = "emergency_siren.wav"
    
    private init() {
        // Always regenerate siren to pick up latest sound synthesis
        prepareSirenFile()
    }
    
    func playEmergencyAlarm() {
        print("[Audio] Playing rapid-burst iOS SOS alarm")
        
        // 1. Maximize System Volume
        maximizeSystemVolume()
        
        // 2. Configure Audio Session to bypass Silent Switch
        do {
            print("[Audio] Configuring AVAudioSession for background playback...")
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[ERROR] [Audio] Failed to set audio session: \(error.localizedDescription)")
        }
        
        // 3. Play the generated siren file
        let fileURL = getSirenFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.numberOfLoops = -1 // Loop infinitely
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                
                let success = audioPlayer?.play() ?? false
                if success {
                    print("✅ [Audio] Siren playback started successfully")
                } else {
                    print("❌ [Audio] AVAudioPlayer failed to start playback (possibly background restriction)")
                    // Fallback to high-pitched system sound
                    AudioServicesPlaySystemSound(1351)
                }
            } catch {
                print("❌ [Audio] Failed to initialize AVAudioPlayer: \(error.localizedDescription)")
                AudioServicesPlaySystemSound(1351)
            }
        } else {
            print("⚠️ [Audio] Siren file not found, synth file if missing...")
            prepareSirenFile()
            AudioServicesPlaySystemSound(1351)
        }
        
        // Haptic feedback as additional layer
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        
        // 4. Trigger Local Notification as high-reliability background fallback
        triggerLocalNotificationAlarm()
    }
    
    private func triggerLocalNotificationAlarm() {
        let content = UNMutableNotificationContent()
        content.title = "EMERGENCY ALERT TRIGGERED"
        content.body = "Open the app immediately to view location and stop the alarm."
        content.sound = .defaultCritical // Requires entitlement, falls back to default if unavailable
        
        // Use a default loud sound if critical category isn't available
        if #available(iOS 12.0, *) {
            content.sound = UNNotificationSound.defaultCritical
        } else {
            content.sound = UNNotificationSound.default
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "EmergencyAlarm-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[ERROR] [Audio] Failed to add local notification: \(error.localizedDescription)")
            } else {
                print("✅ [Audio] Local Notification alarm triggered successfully")
            }
        }
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
        // Only synthesize if file doesn't already exist — avoids blocking I/O on every launch
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[Audio] Siren file already exists, skipping synthesis")
            return
        }
        
        print("[Audio] Synthesizing rapid-burst iOS SOS alarm...")

        let sampleRate: Double = 44100.0
        let duration: Double = 4.0
        let numSamples = Int(duration * sampleRate)
        
        var data = Data()
        addWavHeader(to: &data, sampleRate: Int32(sampleRate), numSamples: Int32(numSamples))
        
        // Pattern: 3 short sharp bursts (each 200ms ON, 150ms OFF) then 350ms rest
        // Total pattern cycle = 3 * (200 + 150) + 350 = 1400ms (~0.71 cycles/sec)
        let burstFreq: Double = 2800.0 // Very high pitch — piercing
        let burstOnMs: Double = 0.18   // 180ms on
        let burstOffMs: Double = 0.12  // 120ms off
        let groupRestMs: Double = 0.4  // 400ms rest between groups
        let burstsPerGroup = 3
        let groupCycle = Double(burstsPerGroup) * (burstOnMs + burstOffMs) + groupRestMs

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            
            // Position within current group cycle
            let tInCycle = t.truncatingRemainder(dividingBy: groupCycle)
            
            // Figure out which burst/rest segment we're in
            var sampleValue: Int16 = 0
            var cursor = 0.0
            var audioActive = false
            
            for _ in 0..<burstsPerGroup {
                let burstStart = cursor
                let burstEnd = cursor + burstOnMs
                cursor = burstEnd + burstOffMs
                
                if tInCycle >= burstStart && tInCycle < burstEnd {
                    let tLocal = tInCycle - burstStart
                    let burstDuration = burstOnMs
                    
                    // Sharp envelope: fast attack (5ms), sustain, fast decay (15ms)
                    let attackTime = 0.005
                    let decayTime  = 0.02
                    var envelope: Double = 1.0
                    if tLocal < attackTime {
                        envelope = tLocal / attackTime
                    } else if tLocal > burstDuration - decayTime {
                        envelope = (burstDuration - tLocal) / decayTime
                    }
                    envelope = max(0, min(1, envelope))
                    
                    let sine = sin(2.0 * .pi * burstFreq * tLocal)
                    sampleValue = Int16(sine * envelope * 32767.0)
                    audioActive = true
                    break
                }
            }
            
            if !audioActive {
                sampleValue = 0
            }
            
            withUnsafeBytes(of: sampleValue.littleEndian) { data.append(contentsOf: $0) }
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ [Audio] Rapid-burst iOS SOS alarm synthesized")
        } catch {
            print("❌ [Audio] Failed to synthesize alarm: \(error.localizedDescription)")
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
