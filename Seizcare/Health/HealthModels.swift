//
//  HealthModels.swift
//  Seizcare
//

import Foundation

struct SleepData: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Double // In hours
}
