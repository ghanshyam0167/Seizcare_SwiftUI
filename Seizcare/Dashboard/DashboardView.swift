import SwiftUI
import Charts
import CoreLocation

// MARK: - Active Chart

enum ActiveChart: Identifiable {
    case seizureFrequency
    case sleepVsSeizures
    case streak
    case triggerCorrelation
    case heartRateTimeline(SeizureRecord)

    var id: String {
        switch self {
        case .seizureFrequency: return "freq"
        case .sleepVsSeizures: return "sleep"
        case .streak: return "streak"
        case .triggerCorrelation: return "trigger"
        case .heartRateTimeline(let r): return "hr-\(r.id.uuidString)"
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {

    @Binding var selectedTab: Tab

    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var emergencyVM = EmergencyViewModel()

    @State private var showLocationSettingsAlert = false

    init(selectedTab: Binding<Tab>, recordsVM: RecordsViewModel, healthVM: HealthViewModel) {
        self._selectedTab = selectedTab
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                recordsVM: recordsVM,
                healthVM: healthVM
            )
        )
    }

    // MARK: - Computed

    private var records: [SeizureRecord] { viewModel.records }
    private var sleep: [SleepData] { viewModel.sleepData }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.dashBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header
                    DashboardHeaderView()

                    // Hero Card
                    HeroCardView(
                        records: records,
                        sleepHours: viewModel.avgSleep7Days,
                        heartRate: viewModel.currentHeartRate,
                        onSendAlert: handleEmergency
                    )

                    // Analysis Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Analysis", icon: "chart.xyaxis.line")

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {

                            GraphCard(
                                title: "Frequency",
                                color: .dashSeizure
                            ) {
                                SeizureFrequencyMiniChart(
                                    records: records,
                                    range: viewModel.frequencyRange
                                )
                            } onTap: {
                                viewModel.activeChart = .seizureFrequency
                            }

                            GraphCard(
                                title: "Sleep",
                                color: .dashSleep
                            ) {
                                SleepVsSeizuresMiniChart(
                                    records: records,
                                    sleep: sleep
                                )
                            } onTap: {
                                viewModel.activeChart = .sleepVsSeizures
                            }

                            GraphCard(
                                title: "Triggers",
                                color: .orange
                            ) {
                                TriggerCorrelationMiniChart(records: records)
                            } onTap: {
                                viewModel.activeChart = .triggerCorrelation
                            }

                            GraphCard(
                                title: "Streak",
                                color: .green
                            ) {
                                SeizureStreakMiniChart(records: records)
                            } onTap: {
                                viewModel.activeChart = .streak
                            }
                        }
                    }

                    // Recent Records
                    RecentRecordsView(records: records) {
                        withAnimation {
                            selectedTab = .records
                        }
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Toast Overlay
            emergencyToast

            // Countdown Overlay
            emergencyCountdown
        }
        .fullScreenCover(item: $viewModel.activeChart) { chart in
            switch chart {
            case .seizureFrequency:
                SeizureFrequencyChartView(records: records, initialRange: viewModel.frequencyRange)
            case .sleepVsSeizures:
                SleepVsSeizuresChartView(records: records, sleep: sleep)
            case .streak:
                SeizureStreakChartView(records: records)
            case .triggerCorrelation:
                TriggerCorrelationChartView(records: records)
            case .heartRateTimeline(let rec):
                HeartRateTimelineChartView(record: rec)
            }
        }
        .alert("Location Access Required", isPresented: $showLocationSettingsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        } message: {
            Text("Enable location to send emergency alerts.")
        }
        .toolbar(emergencyVM.status == .countingDown ? .hidden : .visible, for: .bottomBar)
    }

    // MARK: - Emergency Logic

    private func handleEmergency() {
        if locationManager.location == nil {
            if locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted {
                showLocationSettingsAlert = true
            } else {
                locationManager.requestWhenInUseAuthorization()
                emergencyVM.errorMessage = "Waiting for location..."
                emergencyVM.status = .failed
            }
        } else {
            emergencyVM.startEmergencyCountdown(location: locationManager.location)
        }
    }

    // MARK: - Overlays

    private var emergencyToast: some View {
        Group {
            if emergencyVM.status != .idle && emergencyVM.status != .countingDown {
                VStack {
                    HStack {
                        Text(emergencyVM.status.rawValue)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .padding(.top, 40)

                    Spacer()
                }
                .transition(.move(edge: .top))
            }
        }
    }

    private var emergencyCountdown: some View {
        Group {
            if emergencyVM.status == .countingDown {
                ZStack {
                    Color.black.opacity(0.95).ignoresSafeArea()

                    VStack(spacing: 30) {
                        Text("EMERGENCY ALERT")
                            .foregroundColor(.white)

                        Text("\(emergencyVM.countdownTime)")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.red)

                        Button("Cancel") {
                            emergencyVM.cancelEmergencyAlert()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}