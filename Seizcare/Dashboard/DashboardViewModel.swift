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
    
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    var records: [SeizureRecord] { recordsVM.records }
    var sleepData: [SleepData] { healthVM.sleepData }
    var currentHeartRate: Double { healthVM.currentHeartRate }
    var displayHeartRate: Double? { healthVM.displayHeartRate }
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
