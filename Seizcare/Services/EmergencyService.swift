//
//  EmergencyService.swift
//  Seizcare
//

import Foundation

class EmergencyService {
    static let shared = EmergencyService()
    
    // Supabase config
    // Note: To be aligned with SupabaseService
    private let edgeFunctionURL = URL(string: "https://ydbudbenyxrfwdzumxbu.supabase.co/functions/v1/smooth-service")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkYnVkYmVueXhyZndkenVteGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQzMzcsImV4cCI6MjA5MTkyMDMzN30.ydIKpaJGRWNeusSN-Aa4LGy8Hh_evmILnv9Z0ZRs4mw"

    // Debounce / Cooldown management
    private var lastTriggerTime: Date?
    private let cooldownSeconds: TimeInterval = 60 // Prevent multiple triggers in 60 seconds
    
    private init() {}
    
    /// Triggers an emergency alert using the latest location coordinates and currently authenticated user.
    func triggerEmergencyAlert(latitude: Double, longitude: Double, contacts: [EmergencyContact] = []) async throws {
        // 1. Debounce Check
        if let lastTrigger = lastTriggerTime, Date().timeIntervalSince(lastTrigger) < cooldownSeconds {
            print("⏳ [EmergencyService] Alert aborted due to cooldown.")
            throw EmergencyError.cooldownActive
        }
        
        // 2. Auth Check
        guard let currentUserId = await SupabaseService.shared.currentUserId() else {
            print("❌ [EmergencyService] No authenticated user found.")
            throw EmergencyError.unauthenticated
        }
        
        // 3. Mark the trigger time
        self.lastTriggerTime = Date()
        
        // 4. Construct the SMS message locally if required by the Edge Function or for logging
        let mapLink = "https://maps.google.com/?q=\(latitude),\(longitude)"
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        let timeString = dateFormatter.string(from: Date())
        
        let contactsList = contacts.map { "\($0.name) (\($0.contactNumber))" }.joined(separator: ", ")
        
        let messageLog = """
        🚨 EMERGENCY ALERT
        Possible seizure detected.
        
        🕒 Time: \(timeString)
        📍 Location: \(mapLink)
        👥 Contacts notified: \(contactsList.isEmpty ? "None" : contactsList)
        
        Immediate assistance required.
        """
        print("📲 [EmergencyService] Prepared Alert:\n\(messageLog)")
        
        // 5. Payload Construction
        let contactDTOs = contacts.map { [
            "name": $0.name,
            "contact_number": $0.contactNumber
        ] }
        
        let payload: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "user_id": currentUserId.uuidString,
            "contacts": contactDTOs
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw EmergencyError.serializationFailed
        }
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody
        
        print("🚀 [EmergencyService] Initiating Twilio API Request to Edge Function...")
        
        // 6. DB Storage: Save Seizure Record and Notification
        Task {
            do {
                // 6.1 Create Seizure Record
                let seizureRecord = SeizureRecord(
                    id: UUID(),
                    userId: currentUserId,
                    entryType: .automatic,
                    startTime: Date(),
                    endTime: nil,
                    type: .moderate, // Default for auto-detected
                    triggers: [],
                    location: "Lat: \(latitude), Lon: \(longitude)",
                    notes: "Automatically detected seizure alert."
                )
                
                // 6.2 Create App Notification
                let appNotification = AppNotification(
                    id: UUID(),
                    userId: currentUserId,
                    title: "seizure_detected",
                    message: "moderate_seizure_desc",
                    type: .seizure,
                    date: Date(),
                    isRead: false
                )
                
                // Parallel insertions
                async let saveRecord: () = SupabaseService.shared.insertSeizureRecord(seizureRecord)
                async let saveNotification: () = SupabaseService.shared.insertNotification(appNotification)
                
                _ = try await [saveRecord, saveNotification]
                
                print("✅ [EmergencyService] Seizure record and notification stored in database.")
            } catch {
                print("❌ [EmergencyService] Failed to store alert data: \(error.localizedDescription)")
            }
        }
        
        // 7. Retry Logic via Task for Twilio (Keep existing logic)
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await executeRequestWithRetry(request: request, attempts: 3, continuation: continuation)
            }
        }
    }
    
    private func executeRequestWithRetry(request: URLRequest, attempts: Int, continuation: CheckedContinuation<Void, Error>) async {
        for attempt in 1...attempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EmergencyError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    print("✅ [IPHONE-SOS] Emergency Alert Sent Successfully via Twilio API on attempt \(attempt).")
                    continuation.resume()
                    return
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown HTTP Error"
                    print("⚠️ [EmergencyService] Attempt \(attempt) failed HTTP \(httpResponse.statusCode): \(errorMessage)")
                    throw EmergencyError.httpError(statusCode: httpResponse.statusCode)
                }
            } catch {
                print("⚠️ [EmergencyService] Attempt \(attempt) error: \(error.localizedDescription)")
                if attempt == attempts {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Backoff delay before retry (2 seconds)
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    // Task cancelled during sleep
                    continuation.resume(throwing: error)
                    return
                }
            }
        }
    }
}

enum EmergencyError: Error, LocalizedError {
    case cooldownActive
    case unauthenticated
    case serializationFailed
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .cooldownActive:
            return "Please wait before sending another alert."
        case .unauthenticated:
            return "User is not authenticated."
        case .serializationFailed:
            return "Failed to construct the data payload."
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code):
            return "Server responded with HTTP \(code)"
        }
    }
}
