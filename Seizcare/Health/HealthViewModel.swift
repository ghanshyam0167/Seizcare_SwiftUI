//
//  HealthViewModel.swift
//  Seizcare
//

import Foundation
import Combine

class HealthViewModel: ObservableObject {
    @Published var currentHeartRate: Double = 0
    @Published var currentSpO2: Double = 0
    @Published var heartRateHistory: [Double] = []
    @Published var sleepData: [SleepData] = []
    @Published var lastNightSleep: Double = 0
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    @Published var guidanceText: String = ""
    
    // MARK: - Advanced HR Handling State
    /// RAW Pipeline: Buffer of recent heart rate points for detection and filtering
    private var hrBuffer: [HRPoint] = []
    
    /// UI Pipeline: The stable, confirmed heart rate value shown to the user
    @Published var displayHeartRate: Double? = nil
    
    /// Flag indicating if the heart rate stream is currently receiving fresh data
    @Published var isStreamActive: Bool = false
    
    // MARK: - Freshness Tracking
    /// Timestamp of the most recent HR sample from HealthKit
    private(set) var heartRateTimestamp: Date? = nil
    
    /// UI Freshness: 15s is the threshold for general UI "health" status
    private let heartRateFreshnessThreshold: TimeInterval = 15
    
    /// Stream Loss: 15s is the threshold for marking the stream as "Inactive" (showing "-")
    private let streamLossThreshold: TimeInterval = 15
    
    private var stalenessTimer: AnyCancellable?
    private var loadingTimeout: AnyCancellable?
    
    private let hkManager = HealthKitManager.shared

    private enum GuidanceKey {
        static let connectWatch = "connect_apple_watch_start_monitoring"
        static let waitingForData = "waiting_for_watch_data"
    }
    
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
                self?.handleIncomingHeartRate(bpm, timestamp: Date())
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.isLoading {
                print("[VM] HealthViewModel: Loading timeout reached, clearing spinner")
                self.isLoading = false
            }
        }
    }
    
    private func startDataCollection() {
        hkManager.heartRateUpdateHandler = { [weak self] bpm in
            self?.handleIncomingHeartRate(bpm, timestamp: Date())
        }
        hkManager.heartRateTimestampHandler = { [weak self] date in
            self?.heartRateTimestamp = date
        }
        
        hkManager.startHeartRateStreaming()
        print("[VM] HealthViewModel: HR Streaming started")
        
        hkManager.spo2UpdateHandler = { [weak self] spo2 in
            DispatchQueue.main.async {
                print("[VM] HealthViewModel: SpO2 update received: \(spo2)%")
                self?.currentSpO2 = spo2
                WatchConnectivityManager.shared.sendSpO2ToWatch(spo2)
            }
        }
        hkManager.startSpO2Streaming()
        
        hkManager.fetchLatestHeartRate { [weak self] bpm, sampleDate in
            DispatchQueue.main.async {
                if let bpm = bpm, let sampleDate = sampleDate {
                    let age = Date().timeIntervalSince(sampleDate)
                    if age <= (self?.heartRateFreshnessThreshold ?? 15) {
                        self?.handleIncomingHeartRate(bpm, timestamp: sampleDate)
                    } else {
                        self?.displayHeartRate = nil
                        self?.currentHeartRate = 0
                    }
                }
                self?.isLoading = false
            }
        }
        
        fetchSpO2()
        fetchSleep()
        startStalenessChecker()
        startLoadingTimeout()
    }
    
    // MARK: - Core Heart Rate Pipelines
    
    /// Entry point for ALL incoming heart rate data
    private func handleIncomingHeartRate(_ bpm: Double, timestamp: Date) {
        let newPoint = HRPoint(value: bpm, timestamp: timestamp)
        
        // --- DETECTION PIPELINE (RAW) ---
        // Immediately process for seizure detection (Step 3: No delay, no filtering)
        processForSeizureDetection(bpm)
        
        // --- UI PIPELINE (FILTERED) ---
        // Step 2: Append to buffer and maintain constraints
        hrBuffer.append(newPoint)
        
        // Prune the buffer: keep last 7 values OR values within 12 seconds
        let windowLimit = Date().addingTimeInterval(-12)
        hrBuffer = hrBuffer.filter { $0.timestamp > windowLimit }
        if hrBuffer.count > 7 {
            hrBuffer.removeFirst(hrBuffer.count - 7)
        }
        
        print("[BUFFER] Count: \(hrBuffer.count), Latest: \(Int(bpm)) BPM")
        
        // Step 4 & 5 & 6: Process for UI display
        updateUIDisplay()
        
        // Sync with Watch & Local State
        self.heartRateTimestamp = timestamp
        self.isStreamActive = true
        self.isLoading = false
        self.guidanceText = ""
    }
    
    /// RAW Pipeline: Seizure spike detection
    private func processForSeizureDetection(_ value: Double) {
        print("[RAW] Processing HR: \(Int(value)) BPM")
        
        // Step 4: Baseline = average of last 3 valid values
        let validValues = hrBuffer.map { $0.value }
        let baseline: Double
        if validValues.count >= 3 {
             baseline = validValues.suffix(3).reduce(0, +) / 3.0
        } else {
            baseline = value // Temporary baseline
        }
        
        // Step 5: Spike Detection (RAW)
        let delta = value - baseline
        print("[BASELINE] \(Int(baseline)), Delta: \(Int(delta))")
        
        if delta >= 25 {
            print("[SPIKE-DETECTED] Delta of \(Int(delta)) BPM (Raw) exceeds 25 BPM threshold!")
            // Trigger emergency spike alert
            NotificationCenter.default.post(name: NSNotification.Name("EmergencySpikeDetected"), object: nil, userInfo: ["bpm": value, "delta": delta])
        }
    }
    
    /// UI Pipeline: Stable, confirmed display value
    private func updateUIDisplay() {
        guard let latestPoint = hrBuffer.last else {
            self.displayHeartRate = nil
            self.currentHeartRate = 0
            return
        }
        
        let value = latestPoint.value
        let validValues = hrBuffer.map { $0.value }
        let baseline = validValues.dropLast().suffix(3).reduce(0, +) / max(1, Double(min(3, validValues.count - 1)))
        
        // Step 7: Stream Reliability check (At least 2 readings in last 8s)
        let eightSecondsAgo = Date().addingTimeInterval(-8)
        let recentPointCount = hrBuffer.filter { $0.timestamp > eightSecondsAgo }.count
        let streamIsReliable = recentPointCount >= 2
        
        // Step 6: UI Spike Confirmation
        // 1. At least 2 readings >= baseline + 15
        let spikeReadings = hrBuffer.filter { $0.value >= (baseline + 15) }
        let isConfirmedSpike = (spikeReadings.count >= 2 && latestPoint.value >= baseline + 15)
        
        // Step 12: Confidence Score
        var confidence: Double = 0
        if recentPointCount >= 2 { confidence += 0.4 }
        if isConfirmedSpike { confidence += 0.3 }
        // Self-consistency check (std dev equivalent)
        if hrBuffer.count >= 3 {
            let avg = validValues.reduce(0, +) / Double(validValues.count)
            let variance = validValues.map { pow($0 - avg, 2) }.reduce(0, +) / Double(validValues.count)
            if sqrt(variance) < 10 { confidence += 0.3 }
        }
        
        print("[STREAM] Reliable: \(streamIsReliable), Confirmed Spike: \(isConfirmedSpike), Confidence: \(String(format: "%.1f", confidence))")
        
        // Step 9: UI Display Selection
        if streamIsReliable || isConfirmedSpike || confidence >= 0.6 {
            print("[UI] Displaying confirmed value: \(Int(value))")
            self.displayHeartRate = value
            self.currentHeartRate = value
            self.heartRateHistory.append(value)
            WatchConnectivityManager.shared.sendHeartRateToWatch(value)
            
            if heartRateHistory.count > 100 { heartRateHistory.removeFirst() }
        } else {
            print("[UI] Stream unstable, keeping previous or show dash if first run")
        }
    }
    
    private func startStalenessChecker() {
        stalenessTimer?.cancel()
        stalenessTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Step 8: Fast Stream Loss Detection (> 5s)
                if let ts = self.heartRateTimestamp {
                    let age = Date().timeIntervalSince(ts)
                    
                    if age > self.streamLossThreshold && self.isStreamActive {
                        print("[STREAM] Loss detected (\(Int(age))s) — clearing buffer and marking inactive")
                        self.hrBuffer.removeAll()
                        self.isStreamActive = false
                        self.displayHeartRate = nil
                        self.currentHeartRate = 0
                        self.guidanceText = GuidanceKey.connectWatch
                        WatchConnectivityManager.shared.sendHeartRateToWatch(0)
                        
                        // Stop background streams to save battery (Step 11)
                        self.hkManager.stopHeartRateStreaming()
                        self.hkManager.stopSpO2Streaming()
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
                    print("[VM] Loading timeout reached")
                    self?.isLoading = false
                    self?.guidanceText = GuidanceKey.waitingForData
                }
            }
    }

    private func stopDataCollection() {
        print("[VM] HealthViewModel: Stopping data collection")
        loadingTimeout?.cancel()
        stalenessTimer?.cancel()
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.displayHeartRate = nil
            self.currentHeartRate = 0
            self.isStreamActive = false
            self.hrBuffer.removeAll()
            self.guidanceText = GuidanceKey.connectWatch
            WatchConnectivityManager.shared.sendHeartRateToWatch(0)
        }
        
        hkManager.stopHeartRateStreaming()
        hkManager.stopSpO2Streaming()
    }
    
    func fetchSpO2() {
        hkManager.fetchLatestSpO2 { [weak self] spo2 in
            DispatchQueue.main.async {
                if let spo2 = spo2 {
                    self?.currentSpO2 = spo2
                    WatchConnectivityManager.shared.sendSpO2ToWatch(spo2)
                }
            }
        }
    }
    
    func fetchSleep() {
        hkManager.fetchLastNightSleep { [weak self] hours in
            guard let self = self else { return }
            self.lastNightSleep = hours
            WatchConnectivityManager.shared.sendSleepToWatch(hours)
        }
    }
    
    func fetchSleepFromSupabase() async {
        guard let userId = await SupabaseService.shared.currentUserId() else { return }
        do {
            let supabaseRecords = try await SupabaseService.shared.fetchSleepRecords(userId: userId)
            await MainActor.run {
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
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}
