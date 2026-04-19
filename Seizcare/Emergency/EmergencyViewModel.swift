//
//  EmergencyViewModel.swift
//  Seizcare
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import AudioToolbox

enum EmergencyStatus: String {
    case idle = "Ready"
    case countingDown = "Sending in..."
    case sending = "Sending Alert..."
    case success = "Alert Sent Successfully!"
    case failed = "Failed to Send Alert"
}

class EmergencyViewModel: ObservableObject {
    @Published var status: EmergencyStatus = .idle
    @Published var errorMessage: String? = nil
    @Published var countdownTime: Int = 10
    
    private var countdownTask: Task<Void, Never>?
    
    func startEmergencyCountdown(location: CLLocation?) {
        guard let location = location else {
            self.errorMessage = "Location unavailable. Cannot send alert."
            self.status = .failed
            return
        }
        
        self.status = .countingDown
        self.errorMessage = nil
        self.countdownTime = 10
        
        // Initial feedback
        AudioServicesPlaySystemSound(1105)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        // Cancel any existing task
        countdownTask?.cancel()
        
        countdownTask = Task {
            for i in stride(from: 10, to: 0, by: -1) {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.countdownTime = i
                    // Cumulative feedback: Sound + Vibrate
                    AudioServicesPlaySystemSound(1105) // Tock
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            if !Task.isCancelled {
                // Countdown finished! Trigger SIREN immediately
                await MainActor.run {
                    EmergencyAudioManager.shared.playEmergencyAlarm()
                    // Start the actual network request
                    self.sendEmergencyAlert(location: location)
                }
            }
        }
    }
    
    func cancelEmergencyAlert() {
        countdownTask?.cancel()
        resetToIdle()
    }
    
    func resetToIdle() {
        self.status = .idle
        self.errorMessage = nil
        EmergencyAudioManager.shared.stopAlarm()
    }
    
    func sendEmergencyAlert(location: CLLocation?) {
        guard let location = location else {
            self.errorMessage = "Location unavailable. Cannot send alert."
            self.status = .failed
            return
        }
        
        self.status = .sending
        self.errorMessage = nil
        
        Task {
            do {
                let contacts = EmergencyContactDataModel.shared.getContactsForCurrentUser()
                try await EmergencyService.shared.triggerEmergencyAlert(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    contacts: contacts
                )
                await MainActor.run {
                    self.status = .success
                }
            } catch {
                await MainActor.run {
                    if let emergencyError = error as? EmergencyError, case .cooldownActive = emergencyError {
                        self.errorMessage = "Alert already flagged. Please wait."
                        self.status = .idle // Revert logically
                    } else {
                        self.errorMessage = error.localizedDescription
                        self.status = .failed
                    }
                }
            }
        }
    }
}
