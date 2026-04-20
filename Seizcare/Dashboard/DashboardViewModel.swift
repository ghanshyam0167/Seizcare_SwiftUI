//
//  DashboardViewModel.swift
//  Seizcare
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var recordsVM: RecordsViewModel
    @Published var healthVM: HealthViewModel
    
    @Published var activeChart: ActiveChart?
    @Published var frequencyRange: TimeFrameRange = .weekly
    @Published var hasIncompleteSeizure: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func checkForIncompleteSeizure() async {
        guard let userId = await SupabaseService.shared.currentUserId() else { return }
        do {
            let incomplete = try await SupabaseService.shared.fetchLatestIncompleteSeizure(userId: userId)
            DispatchQueue.main.async {
                self.hasIncompleteSeizure = (incomplete != nil)
            }
        } catch {
            print("[VM] Error checking for incomplete seizure: \(error)")
        }
    }
    
    init(recordsVM: RecordsViewModel, healthVM: HealthViewModel = HealthViewModel()) {
        print("[VM] DashboardViewModel: Initialized with Records and Health dependencies")
        self.recordsVM = recordsVM
        self.healthVM = healthVM
        
        // Forward changes from sub-viewmodels if needed
        recordsVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        healthVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // Sync with Watch alerts
        NotificationCenter.default.publisher(for: NSNotification.Name("WatchTriggeredAlert"))
            .sink { [weak self] _ in
                print("[VM] Watch alert detected — refreshing records")
                Task {
                    await self?.recordsVM.fetchRecords()
                    await self?.checkForIncompleteSeizure()
                }
            }
            .store(in: &cancellables)
            
        // Sync with manual logs
        NotificationCenter.default.publisher(for: NSNotification.Name("ManualSeizureLogged"))
            .sink { [weak self] _ in
                print("[VM] Manual alert detected — refreshing records")
                Task {
                    await self?.recordsVM.fetchRecords()
                    await self?.checkForIncompleteSeizure()
                }
            }
            .store(in: &cancellables)
    }
    
    var records: [SeizureRecord] { recordsVM.records }
    var sleepData: [SleepData] { healthVM.sleepData }
    var currentHeartRate: Double { healthVM.currentHeartRate }
    var displayHeartRate: Double? { healthVM.displayHeartRate }
    var displayHeartRateText: String { healthVM.displayHeartRateText }
    var hasHeartRateValue: Bool { healthVM.hasHeartRateValue }
    var guidanceText: String { healthVM.guidanceText }
    var isLoading: Bool { recordsVM.isLoading || healthVM.isLoading }
    var errorMessage: String? { recordsVM.errorMessage ?? healthVM.errorMessage }
    
    var avgSleep7Days: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.reduce(0) { $0 + $1.duration } / Double(sleepData.count)
    }
    
    var controlPercent: Double {
        let thisMonthCount = records.filter {
            Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .month)
        }.count
        return max(0, 1.0 - Double(thisMonthCount) / 12.0)
    }
    
    var recentRecord: SeizureRecord? { records.first }
}
