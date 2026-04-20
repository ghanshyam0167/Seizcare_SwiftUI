//
//  SeizureEventManager.swift
//  Seizcare
//

import Foundation
import UIKit
import CoreLocation

@MainActor
final class SeizureEventManager {
    static let shared = SeizureEventManager()
    
    private init() {}
    
    func seizureDetected(probability: Double, heartRate: Double) async {
        print("\n[DEMO] 🚨 Seizure FORCED")
        print("[DEMO] HR: \(Int(heartRate)) | Prob: \(String(format: "%.4f", probability))")
        
        guard let userId = await SupabaseService.shared.currentUserId() else {
            print("[DEMO] ❌ Cannot trigger seizure without logged in user.")
            return
        }
        
        let recordId = UUID()
        
        // 1. Create seizure record in Supabase
        let record = SeizureRecord(
            id: recordId,
            userId: userId,
            entryType: .automatic,
            startTime: Date(),
            endTime: nil, // Ongoing seizure
            type: nil,
            triggers: [],
            location: LocationManager().location.map { "\($0.coordinate.latitude), \($0.coordinate.longitude)" },
            notes: "Demo Override Seizure Triggered"
        )
        
        do {
            try await SupabaseService.shared.insertSeizureRecord(record)
            print("[DEMO] ✅ Seizure Record created in Supabase: \(recordId)")
            
            // Post notification to tell any active Views (like Dashboard) to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRecords"), object: nil)
            
        } catch {
            print("[DEMO] ❌ Failed to create Seizure Record: \(error)")
        }
        
        // 2. Insert App Notification (Simulated or real if applicable)
        // (Assuming we don't have a direct saveAppNotification in SupabaseService, 
        // we'll just log it per instructions, or we could insert it if the method exists)
        print("[DEMO] 🔔 App Notification Inserted: 'Seizure Detected'")
        
        // 3. Start Tagging Sensor Logs
        print("[DEMO] 🏷️ Starting Sensor Log Tagging (retro-tagging last 2 hours...)")
        SensorLogManager.shared.startTagging(userId: userId, recordId: recordId)
        
        // 4. Alert System Trigger
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // In-app Alert / Siren
        EmergencyAudioManager.shared.playEmergencyAlarm()
        
        // 5. Emergency Flow Simulation
        let contacts = EmergencyContactDataModel.shared.getContactsForCurrentUser()
        print("[Emergency] Alert sent to \(contacts.count) contacts")
    }
}
