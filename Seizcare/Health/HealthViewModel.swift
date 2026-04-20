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
    @Published private(set) var lastValidHeartRate: Double?
    
    /// Flag indicating if the heart rate stream is currently receiving fresh data
    @Published var isStreamActive: Bool = false
    
    // MARK: - Freshness Tracking
    /// Timestamp of the most recent HR sample from HealthKit
    private(set) var heartRateTimestamp: Date? = nil
    private(set) var lastUpdateTime: Date? = nil
    private var staleLogBucket: Int = -1
    
    private var stalenessTimer: AnyCancellable?
    private var loadingTimeout: AnyCancellable?
    
    private let hkManager = HealthKitManager.shared

    private enum GuidanceKey {
        static let connectWatch = "connect_apple_watch_start_monitoring"
        static let waitingForData = "waiting_for_watch_data"
    }

    var displayHeartRateText: String {
        if let lastValidHeartRate {
            return "\(Int(lastValidHeartRate)) BPM"
        }
        return "Waiting..."
    }

    var hasHeartRateValue: Bool {
        lastValidHeartRate != nil
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
        guidanceText = ""

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
                    self?.handleIncomingHeartRate(bpm, timestamp: sampleDate)
                } else {
                    self?.logHeartRateStalenessIfNeeded(context: "Initial fetch has no sample yet")
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
        print("[HR] New value: \(bpm)")
        heartRateTimestamp = timestamp
        lastUpdateTime = timestamp
        staleLogBucket = -1

        if bpm > 0 {
            let newPoint = HRPoint(value: bpm, timestamp: timestamp)

            // Keep the raw buffer for seizure detection, but do not gate the UI on it.
            hrBuffer.append(newPoint)

            let windowLimit = Date().addingTimeInterval(-12)
            hrBuffer = hrBuffer.filter { $0.timestamp > windowLimit }
            if hrBuffer.count > 7 {
                hrBuffer.removeFirst(hrBuffer.count - 7)
            }

            print("[BUFFER] Count: \(hrBuffer.count), Latest: \(Int(bpm)) BPM")

            processForSeizureDetection(bpm)
            updateUIDisplay(with: bpm)
            WatchConnectivityManager.shared.sendHeartRateToWatch(bpm)
        } else {
            print("[BUFFER] Received non-positive HR sample: \(bpm) — keeping last valid value")
            refreshDisplayedHeartRate()
        }

        isStreamActive = true
        isLoading = false
        if hasHeartRateValue {
            guidanceText = ""
        }
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
    
    /// UI Pipeline: immediately surface the latest valid value.
    private func updateUIDisplay(with value: Double) {
        lastValidHeartRate = value
        refreshDisplayedHeartRate()

        heartRateHistory.append(value)
        if heartRateHistory.count > 100 {
            heartRateHistory.removeFirst()
        }
    }

    private func refreshDisplayedHeartRate() {
        displayHeartRate = lastValidHeartRate
        currentHeartRate = lastValidHeartRate ?? 0
        print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
    }

    private func logHeartRateStalenessIfNeeded(context: String? = nil) {
        guard let lastUpdateTime else {
            return
        }

        let age = Date().timeIntervalSince(lastUpdateTime)
        guard age >= 15 else {
            staleLogBucket = -1
            return
        }

        let bucket = Int(age / 15)
        guard bucket != staleLogBucket else {
            return
        }

        staleLogBucket = bucket
        if let context {
            print("[HR] Data stale (\(Int(age))s). \(context)")
        } else {
            print("[HR] Data stale (\(Int(age))s since last update)")
        }
        print("[HR] Displaying: \(lastValidHeartRate ?? -1)")
    }
    
    private func startStalenessChecker() {
        stalenessTimer?.cancel()
        stalenessTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.logHeartRateStalenessIfNeeded()
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
            self.isStreamActive = false
            self.refreshDisplayedHeartRate()
            self.guidanceText = GuidanceKey.connectWatch
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
