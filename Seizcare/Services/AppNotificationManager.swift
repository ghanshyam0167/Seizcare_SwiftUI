//
//  AppNotificationManager.swift
//  Seizcare
//

import Foundation
import SwiftUI
import UserNotifications
import UIKit
import Combine

@MainActor
final class AppNotificationManager: ObservableObject {
    static let shared = AppNotificationManager()

    struct InAppAlert: Identifiable, Equatable {
        let id = UUID()
        let titleKey: String
        let messageKey: String
        let recordId: UUID
        let heartRate: Int?
    }

    @Published var activeAlert: InAppAlert? = nil

    private let rest: SupabaseRESTClient
    private let iso = ISO8601DateFormatter()

    init(rest: SupabaseRESTClient? = nil) {
        self.rest = rest ?? SupabaseRESTClient()
    }

    func notifySeizureDetected(userId: UUID, recordId: UUID, heartRate: Int?) async {
        triggerHaptics()
        activeAlert = InAppAlert(
            titleKey: "seizure_detected",
            messageKey: "notifying_contacts",
            recordId: recordId,
            heartRate: heartRate
        )

        await scheduleLocalNotification(heartRate: heartRate)

        do {
            try await insertNotificationRow(userId: userId, heartRate: heartRate)
        } catch {
            print("⚠️ [AppNotificationManager] Failed to insert app_notifications row:", error.localizedDescription)
        }
    }

    private func insertNotificationRow(userId: UUID, heartRate: Int?) async throws {
        struct InsertRow: Encodable {
            let id: String
            let user_id: String
            let title: String
            let message: String
            let notification_type: String
            let is_read: Bool
            let event_date: String
        }

        // Store human-readable text in the DB; the UI maps common phrases to localized strings.
        let title = "Seizure Detected"
        let message = "Emergency contacts are being notified"

        let row = InsertRow(
            id: UUID().uuidString.lowercased(),
            user_id: userId.uuidString.lowercased(),
            title: title,
            message: message,
            notification_type: "seizure_alert",
            is_read: false,
            event_date: iso.string(from: Date())
        )

        let body = try JSONEncoder().encode([row])
        _ = try await rest.request(
            "POST",
            path: "rest/v1/app_notifications",
            jsonBody: body,
            prefer: "return=minimal"
        )
    }

    private func triggerHaptics() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    /// Local notification used as a device-side stand-in for server-driven APNs in demo mode.
    private func scheduleLocalNotification(heartRate: Int?) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "seizure_detected".localized
        if let heartRate {
            content.body = "\("notifying_contacts".localized) (\("heart_rate".localized): \(heartRate) BPM)"
        } else {
            content.body = "notifying_contacts".localized
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("⚠️ [AppNotificationManager] Local notification scheduling failed:", error.localizedDescription)
        }
    }
}
