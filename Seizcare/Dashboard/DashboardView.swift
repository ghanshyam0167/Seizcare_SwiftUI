import SwiftUI
import Charts
import CoreLocation

// MARK: - Active Chart

enum ActiveChart: Identifiable {
    case seizureFrequency
    case sleepVsSeizures
    case heartRateTimeline(SeizureRecord)

    var id: String {
        switch self {
        case .seizureFrequency:          return "freq"
        case .sleepVsSeizures:           return "sleep"
        case .heartRateTimeline(let r):  return "hr-\(r.id.uuidString)"
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
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
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Summary")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.dashLabel)
                            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline)
                                .foregroundStyle(Color.dashSecondary)
                        }
                        Spacer()
                        NavigationLink(destination: SettingsView(vm: authVM)) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundStyle(Color.dashSecondary)
                        }
                    }
                    .padding(.top, 4)

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
                            // Frequency card
                            Button { viewModel.activeChart = .seizureFrequency } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Event Count")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.dashLabel)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.dashTertiary)
                                    }
                                    SeizureFrequencyMiniChart(
                                        records: records,
                                        range: viewModel.frequencyRange
                                    )
                                    .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(14)
                                .background(Color.dashCard)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.dashSeizure.opacity(0.15), lineWidth: 1))
                            }
                            .buttonStyle(ScaleButtonStyle())

                            // Sleep card
                            Button { viewModel.activeChart = .sleepVsSeizures } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Sleep")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.dashLabel)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.dashTertiary)
                                    }
                                    SleepVsSeizuresMiniChart(
                                        records: records,
                                        sleep: sleep
                                    )
                                    .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(14)
                                .background(Color.dashCard)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.dashSleep.opacity(0.15), lineWidth: 1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }

                    // Recent Records
                    RecentRecordsView(records: records) {
                        withAnimation {
                            selectedTab = .records
                        }
                    }
                    .environmentObject(viewModel.recordsVM)

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