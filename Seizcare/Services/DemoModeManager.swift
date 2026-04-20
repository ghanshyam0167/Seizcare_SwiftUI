//
//  DemoModeManager.swift
//  Seizcare
//

import Foundation
import Combine

@MainActor
final class DemoModeManager: ObservableObject {
    private enum Keys {
        static let enabled = "demo_mode_enabled"
        static let autoTriggerSeconds = "demo_auto_trigger_seconds"
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }

    /// Optional: set > 0 to auto-trigger a demo detection after N seconds.
    /// Default: 0 (disabled).
    @Published var autoTriggerSeconds: Int {
        didSet { UserDefaults.standard.set(autoTriggerSeconds, forKey: Keys.autoTriggerSeconds) }
    }

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        let saved = UserDefaults.standard.integer(forKey: Keys.autoTriggerSeconds)
        self.autoTriggerSeconds = saved
    }
}
