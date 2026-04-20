//
//  SeizureDetectionManager.swift
//  Seizcare
//

import Foundation
import Combine

@MainActor
final class SeizureDetectionManager: ObservableObject {
    @Published private(set) var activeRecord: SeizureRecord? = nil
    @Published private(set) var lastDetectedHeartRate: Int? = nil
    @Published private(set) var isDetecting: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let recordService: SeizureRecordService
    private let sensorLogManager: SensorLogManager
    private let notificationManager: AppNotificationManager

    private var autoTriggerTask: Task<Void, Never>?

    init(
        recordService: SeizureRecordService? = nil,
        sensorLogManager: SensorLogManager? = nil,
        notificationManager: AppNotificationManager? = nil
    ) {
        self.recordService = recordService ?? SeizureRecordService()
        self.sensorLogManager = sensorLogManager ?? .shared
        self.notificationManager = notificationManager ?? .shared
    }

    func bootstrapIfNeeded(recordsVM: RecordsViewModel) async {
        guard let userId = await SupabaseService.shared.currentUserId() else { return }
        do {
            if let ongoing = try await recordService.fetchLatestOngoingRecord(userId: userId) {
                activeRecord = ongoing
                recordsVM.upsertFromRemote(ongoing)
                
                // Resume tagging if we're still within the 2-hour window.
                let now = Date()
                let expiresAt = ongoing.startTime.addingTimeInterval(2 * 60 * 60)
                let remaining = expiresAt.timeIntervalSince(now)
                if remaining > 0 {
                    sensorLogManager.startTagging(
                        userId: userId,
                        recordId: ongoing.id,
                        startedAt: ongoing.startTime,
                        maxDuration: remaining
                    )
                }
                
                lastDetectedHeartRate = (try? await sensorLogManager.fetchLatestHeartRate(userId: userId)) ?? lastDetectedHeartRate
            }
        } catch {
            // Non-fatal: demo mode should still work offline.
            print("⚠️ [SeizureDetectionManager] bootstrap fetch ongoing failed:", error.localizedDescription)
        }
    }

    func scheduleAutoTriggerIfNeeded(demoMode: DemoModeManager, recordsVM: RecordsViewModel, healthVM: HealthViewModel) {
        autoTriggerTask?.cancel()
        autoTriggerTask = nil

        guard demoMode.isEnabled else { return }
        let seconds = demoMode.autoTriggerSeconds
        guard seconds > 0 else { return }
        guard activeRecord?.isOngoing != true else { return }

        autoTriggerTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(seconds))
            await self.triggerDemoDetection(demoMode: demoMode, recordsVM: recordsVM, healthVM: healthVM)
        }
    }

    func triggerDemoDetection(demoMode: DemoModeManager, recordsVM: RecordsViewModel, healthVM: HealthViewModel) async {
        guard demoMode.isEnabled else { return }
        guard !isDetecting else { return }
        if activeRecord?.isOngoing == true { return }

        isDetecting = true
        lastErrorMessage = nil
        defer { isDetecting = false }

        guard let userId = await SupabaseService.shared.currentUserId() else {
            lastErrorMessage = "User not authenticated."
            return
        }

        do {
            let record = try await recordService.insertAutoDetectedDemoRecord(userId: userId, startTime: Date())
            activeRecord = record
            recordsVM.upsertFromRemote(record)

            // Start tagging sensor logs (past 2h + future).
            sensorLogManager.startTagging(userId: userId, recordId: record.id, startedAt: record.startTime)

            // Latest HR at detection time (prefer logs; fall back to current stream).
            let hrFromLogs = try? await sensorLogManager.fetchLatestHeartRate(userId: userId)
            let hrFallback = Int(healthVM.displayHeartRate ?? healthVM.currentHeartRate)
            let latestHR = hrFromLogs ?? (hrFallback > 0 ? hrFallback : nil)
            lastDetectedHeartRate = latestHR

            // In-app + push + DB notification.
            await notificationManager.notifySeizureDetected(
                userId: userId,
                recordId: record.id,
                heartRate: latestHR
            )

            // Emergency contacts simulation (console output).
            await simulateEmergencyContactsAlert(userId: userId)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func handleRecordSaved(_ record: SeizureRecord) {
        guard activeRecord?.id == record.id else { return }
        guard record.endTime != nil else { return }
        sensorLogManager.stopTagging(recordId: record.id)
        activeRecord = nil
    }

    private func simulateEmergencyContactsAlert(userId: UUID) async {
        do {
            let dtos = try await SupabaseService.shared.fetchContacts(userId: userId)
            let contacts = dtos.map { $0.toDomain() }
            if contacts.isEmpty {
                print("ℹ️ [SeizureDetectionManager] No emergency contacts to notify.")
            } else {
                for c in contacts {
                    print("📨 [Demo] Notifying emergency contact: \(c.name) (\(c.contactNumber)) — Seizure detected for user \(userId.uuidString.lowercased())")
                }
            }
        } catch {
            print("⚠️ [SeizureDetectionManager] Failed to fetch emergency contacts:", error.localizedDescription)
        }
    }
}
