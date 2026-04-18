//
//  HealthViewModel.swift
//  Seizcare
//

import Foundation
import Combine

class HealthViewModel: ObservableObject {
    @Published var currentHeartRate: Double = 0
    @Published var heartRateHistory: [Double] = []
    @Published var sleepData: [SleepData] = []
    @Published var lastNightSleep: Double = 0
    @Published var isLoading = true
    
    @Published var guidanceText: String = ""
    
    private let hkManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: AnyCancellable?
    private var loadingTimeout: AnyCancellable?
    
    init() {
        setupHealthKit()
        setupNotifications()
        Task { await fetchSleepFromSupabase() }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("StopHealthStream"), object: nil, queue: .main) { [weak self] _ in
            self?.stopDataCollection()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("StartHealthStream"), object: nil, queue: .main) { [weak self] _ in
            self?.startDataCollection()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("WatchHeartRateUpdate"), object: nil, queue: .main) { [weak self] note in
            if let bpm = note.userInfo?["bpm"] as? Double {
                print("[VM] Received direct HR from notification: \(bpm)")
                self?.updateHeartRate(bpm)
            }
        }
    }
    
    private func setupHealthKit() {
        print("[VM] HealthViewModel: Initializing HealthKit setup")
        hkManager.requestAuthorization { success, error in
            if success {
                print("[VM] HealthViewModel: Auth success, starting data collection")
                self.startDataCollection()
            } else {
                print("[VM] HealthViewModel: Auth failed or denied")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        
        // Fallback: Ensure loading screen clears after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading {
                print("[VM] HealthViewModel: Loading timeout reached, clearing spinner")
                self.isLoading = false
            }
        }
    }
    
    private func startDataCollection() {
        // Handle heart rate updates
        hkManager.heartRateUpdateHandler = { [weak self] bpm in
            self?.updateHeartRate(bpm)
        }
        
        hkManager.startHeartRateStreaming()
        print("[VM] HealthViewModel: HR Streaming started")
        
        // Initial fetch for latest HR
        hkManager.fetchLatestHeartRate { [weak self] bpm in
            DispatchQueue.main.async {
                if let bpm = bpm {
                    print("[VM] HealthViewModel: Initial HR fetched: \(bpm)")
                    self?.updateHeartRate(bpm)
                }
                self?.isLoading = false
            }
        }
        
        // Fetch today's sleep
        fetchTodaySleep()
        
        // Start Polling Timer (Fallback every 2 seconds)
        startPolling()
        
        // Start Loading Timeout (10 seconds)
        startLoadingTimeout()
    }
    
    private func startPolling() {
        pollingTimer?.cancel()
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                print("[Timer] Polling HR...")
                self?.hkManager.fetchLatestHeartRate { bpm in
                    if let bpm = bpm {
                        self?.updateHeartRate(bpm)
                    }
                }
            }
    }
    
    private func startLoadingTimeout() {
        loadingTimeout?.cancel()
        loadingTimeout = Just(())
            .delay(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] in
                if self?.isLoading == true {
                    print("[VM] Loading timeout reached - showing guidance")
                    self?.isLoading = false
                    self?.guidanceText = "Waiting for heart rate data... Start a workout on your watch to enable continuous tracking."
                }
            }
    }
    
    private func fetchTodaySleep() {
        hkManager.fetchTodaySleep { [weak self] hours in
            DispatchQueue.main.async {
                self?.lastNightSleep = hours
                self?.isLoading = false
                print("[HK] Sleep Today Updated: \(hours) hours")
                // Sync with Watch
                WatchConnectivityManager.shared.sendSleepDataToWatch(hours)
            }
        }
    }
    
    private func stopDataCollection() {
        print("[VM] HealthViewModel: Stopping data collection")
        hkManager.stopHeartRateStreaming()
    }
    
    func fetchSleepData() {
        hkManager.fetchSleepData(lastDays: 7) { [weak self] data in
            DispatchQueue.main.async {
                self?.sleepData = data
                if let lastNight = data.first {
                    self?.lastNightSleep = lastNight.duration
                    WatchConnectivityManager.shared.sendSleepDataToWatch(lastNight.duration)
                }
                print("[HK] Updated sleepData: \(data.count) entries, last night: \(self?.lastNightSleep ?? 0)h")
            }
        }
    }
    
    /// Fetch 90 days of sleep data from Supabase as a backup/complement to HealthKit.
    func fetchSleepFromSupabase() async {
        guard let userId = await SupabaseService.shared.currentUserId() else { return }
        do {
            let supabaseRecords = try await SupabaseService.shared.fetchSleepRecords(userId: userId)
            await MainActor.run {
                // Merge with HealthKit data — avoid duplicates by date
                let existingDates = Set(sleepData.map { Calendar.current.startOfDay(for: $0.date) })
                let newItems: [SleepData] = supabaseRecords.compactMap { record in
                    let day = Calendar.current.startOfDay(for: record.date)
                    guard !existingDates.contains(day) else { return nil }
                    return SleepData(date: record.date, duration: record.hours)
                }
                if !newItems.isEmpty {
                    sleepData.append(contentsOf: newItems)
                    sleepData.sort { $0.date > $1.date }
                }
            }
        } catch {
            print("[Supabase] Failed to fetch sleep records: \(error.localizedDescription)")
        }
    }
    
    private func updateHeartRate(_ bpm: Double) {
        if bpm != self.currentHeartRate {
            print("[HK] HR Value Updated: \(bpm) BPM")
            self.currentHeartRate = bpm
            self.heartRateHistory.append(bpm)
            self.isLoading = false
            self.guidanceText = "" // Clear guidance if we have data
            
            // Sync with Watch
            WatchConnectivityManager.shared.sendHeartRateToWatch(bpm)
            
            // Keep last 100 samples for history
            if heartRateHistory.count > 100 {
                heartRateHistory.removeFirst()
            }
        }
    }
}
