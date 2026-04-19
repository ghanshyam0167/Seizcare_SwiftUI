//
//  SensorLogBackgroundTasks.swift
//  Seizcare
//
//  Background upload scheduling for sensor logs.
//

import Foundation
import BackgroundTasks

enum SensorLogBackgroundTasks {
    /// Identifier must exist in Info.plist under `BGTaskSchedulerPermittedIdentifiers`.
    static var uploadTaskIdentifier: String {
        // Prefer bundle id so Debug/Release identifiers remain aligned.
        let bid = Bundle.main.bundleIdentifier ?? "gs.Seizcare"
        return bid + ".sensorlog.upload"
    }
    
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: uploadTaskIdentifier, using: nil) { task in
            handle(task: task)
        }
    }
    
    static func schedule(earliestBegin: TimeInterval = 60) {
        let req = BGProcessingTaskRequest(identifier: uploadTaskIdentifier)
        req.requiresNetworkConnectivity = true
        req.requiresExternalPower = false
        req.earliestBeginDate = Date(timeIntervalSinceNow: earliestBegin)
        
        do {
            try BGTaskScheduler.shared.submit(req)
        } catch {
            // Common in Simulator or if Info.plist isn't configured yet.
            print("⚠️ [SensorLogBG] submit failed:", error.localizedDescription)
        }
    }
    
    private static func handle(task: BGTask) {
        // Always schedule the next one, so intermittent connectivity still eventually flushes.
        schedule()
        
        task.expirationHandler = {
            // Nothing to cancel explicitly; uploads are short and will retry later.
            print("⚠️ [SensorLogBG] task expired")
        }
        
        Task {
            let success = await SensorLogPipelineCoordinator.shared.performBackgroundUpload()
            task.setTaskCompleted(success: success)
        }
    }
}

