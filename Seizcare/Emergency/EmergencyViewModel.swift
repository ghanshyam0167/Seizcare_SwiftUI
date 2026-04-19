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
    case idle        = "ready"
    case sending     = "sending_alert"
    case success     = "alert_sent_success"
    case failed      = "alert_sent_failed"
}

class EmergencyViewModel: ObservableObject {
    @Published var status: EmergencyStatus = .idle
    @Published var errorMessage: String? = nil

    // Explicit separate states for alert lifecycle
    @Published var alertSending: Bool = false
    @Published var alertSuccessPopupVisible: Bool = false
    @Published var alarmPlaying: Bool = false
    @Published var currentAlertSessionID: UUID = UUID()

    /// Immediately fires the alert with no countdown (used by slide-to-alert).
    func sendEmergencyAlertImmediately(location: CLLocation?) {
        guard let location = location else {
            print("[Alert] ❌ Location unavailable, cannot send alert")
            self.errorMessage = "location_unavailable"
            self.status = .failed
            self.alertSending = false
            return
        }

        print("[Alert] Swipe triggered")
        print("[Alert] Resetting popup state")

        // 1. Reset popup state first
        self.alertSuccessPopupVisible = false
        self.status = .idle
        self.errorMessage = nil

        // 2. Clear any old state and assign new session ID
        self.currentAlertSessionID = UUID()
        print("[Alert] New session ID: \(self.currentAlertSessionID)")

        // 3. Restart SOUND properly
        if self.alarmPlaying {
            EmergencyAudioManager.shared.stopAlarm()
            self.alarmPlaying = false
        }
        EmergencyAudioManager.shared.playEmergencyAlarm()
        self.alarmPlaying = true
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        // 4. Force RE-PRESENTATION OF POPUP
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[Alert] Showing success popup")
            self.alertSuccessPopupVisible = true
            self.sendEmergencyAlert(location: location)
        }
    }

    func resetToIdle() {
        print("[Alert] Popup dismissed")
        // RESET AFTER DISMISS
        self.alertSuccessPopupVisible = false
        self.status = .idle
        self.alertSending = false
        self.errorMessage = nil
        
        if self.alarmPlaying {
            EmergencyAudioManager.shared.stopAlarm()
            self.alarmPlaying = false
            print("[Alert] Alarm stopped")
        } else {
            // Just in case it was playing but state got out of sync
            EmergencyAudioManager.shared.stopAlarm()
            print("[Alert] Alarm stopped forcefully")
        }
    }

    func sendEmergencyAlert(location: CLLocation?) {
        guard let location = location else {
            self.errorMessage = "location_unavailable"
            self.status = .failed
            self.alertSending = false
            return
        }

        self.status = .sending
        self.alertSending = true
        self.errorMessage = nil
        print("[Alert] Sending alert — status: sending")

        Task {
            do {
                let contacts = EmergencyContactDataModel.shared.getContactsForCurrentUser()
                try await EmergencyService.shared.triggerEmergencyAlert(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    contacts: contacts
                )
                await MainActor.run {
                    print("[Alert] ✅ Alert sent successfully")
                    self.status = .success
                    self.alertSending = false
                }
            } catch {
                await MainActor.run {
                    print("[Alert] ❌ Alert failed: \(error.localizedDescription)")
                    if let emergencyError = error as? EmergencyError,
                       case .cooldownActive = emergencyError {
                        self.errorMessage = "alert_cooldown"
                        self.status = .idle
                    } else {
                        self.errorMessage = error.localizedDescription
                        self.status = .failed
                    }
                    self.alertSending = false
                }
            }
        }
    }
}
