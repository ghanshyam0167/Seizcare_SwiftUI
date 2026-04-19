//
//  WatchAudioManager.swift
//  Seizcare watch app Watch App
//

import Foundation
import WatchKit
import AVFoundation

class WatchAudioManager {
    static let shared = WatchAudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let sirenFileName = "watch_emergency_siren.wav"
    
    private init() {
        prepareSirenFile()
    }
    
    func playEmergencyAlarm() {
        print("[Watch-Audio] Playing reliable digital SOS siren on Watch")
        
        // 1. Configure Audio Session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[Watch-Audio] Failed to set audio session: \(error.localizedDescription)")
        }
        
        // 2. Play the synthesized siren
        let fileURL = getSirenFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                print("✅ [Watch-Audio] Alarm started on wrist")
            } catch {
                print("❌ [Watch-Audio] Failed to play siren: \(error.localizedDescription)")
            }
        }
    }
    
    func stopAlarm() {
        print("[Watch-Audio] Stopping alarm")
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func getSirenFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(sirenFileName)
    }
    
    private func prepareSirenFile() {
        let fileURL = getSirenFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) { return }
        
        print("[Watch-Audio] Synthesizing Watch siren WAV...")
        
        let sampleRate: Double = 44100.0
        let duration: Double = 3.0
        let numSamples = Int(duration * sampleRate)
        
        var data = Data()
        addWavHeader(to: &data, sampleRate: Int32(sampleRate), numSamples: Int32(numSamples))
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let freqOscillation = sin(2.0 * .pi * t / 0.75)
            let currentFreq = 1200.0 + (freqOscillation * 400.0)
            let sampleValue = Int16(sin(2.0 * .pi * currentFreq * t) * 32767.0)
            withUnsafeBytes(of: sampleValue.littleEndian) { data.append(contentsOf: $0) }
        }
        
        do {
            try data.write(to: fileURL)
            print("✅ [Watch-Audio] Siren synthesized on Watch")
        } catch {
            print("❌ [Watch-Audio] Failed to synthesize Watch siren: \(error.localizedDescription)")
        }
    }
    
    private func addWavHeader(to data: inout Data, sampleRate: Int32, numSamples: Int32) {
        let byteRate = sampleRate * 2
        let totalDataSize = numSamples * 2
        data.append("RIFF".data(using: .ascii)!)
        withUnsafeBytes(of: (36 + totalDataSize).littleEndian) { data.append(contentsOf: $0) }
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        withUnsafeBytes(of: Int32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: sampleRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(2).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(16).littleEndian) { data.append(contentsOf: $0) }
        data.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: totalDataSize.littleEndian) { data.append(contentsOf: $0) }
    }
}
