//
//  DashboardView.swift
//  Seizcare
//

import SwiftUI
import SwiftData
import Charts
import CoreLocation

// MARK: - Active Chart Enum

enum ActiveChart: Identifiable {
    case seizureFrequency
    case sleepVsSeizures
    case streak
    case triggerCorrelation
    case heartRateTimeline(SeizureRecord)

    var id: String {
        switch self {
        case .seizureFrequency:         return "freq"
        case .sleepVsSeizures:          return "sleep"
        case .streak:                   return "streak"
        case .triggerCorrelation:       return "trigger"
        case .heartRateTimeline(let r): return "hr-\(r.id.uuidString)"
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var vm: RecordsViewModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var emergencyVM = EmergencyViewModel()
    @State private var activeChart: ActiveChart?
    @State private var frequencyRange: TimeFrameRange = .weekly
    @State private var showLocationSettingsAlert = false

    private var records: [SeizureRecord] { vm.records }
    private let sleep   = MockDashboardData.sleepRecords

    private var recentRecord: SeizureRecord? { records.first }
    private var avgSleep7Days: Double {
        let recent = sleep.prefix(7)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.hours } / Double(recent.count)
    }

    // Seizure control: inverse of seizure frequency relative to max expected (3/week)
    private var controlPercent: Double {
        let thisMonthCount = records.filter {
            Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .month)
        }.count
        return max(0, 1.0 - Double(thisMonthCount) / 12.0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.dashBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Header ──────────────────────────────
                    DashboardHeaderView()

                    // ── Hero Card ───────────────────────────
                    HeroCardView(
                        records: records,
                        sleepRecords: sleep,
                        onSendAlert: { 
                            if locationManager.location == nil {
                                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                    showLocationSettingsAlert = true
                                } else {
                                    locationManager.requestWhenInUseAuthorization()
                                    withAnimation {
                                        emergencyVM.errorMessage = "Waiting for location connection... Please ensure GPS is enabled and try again."
                                        emergencyVM.status = .failed
                                    }
                                }
                            } else {
                                withAnimation {
                                    emergencyVM.startEmergencyCountdown(location: locationManager.location)
                                }
                            }
                        }
                    )

                    // ── Analysis Cards ───────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Analysis", icon: "chart.xyaxis.line")
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            
                            // 1. FREQUENCY CARD
                            Button(action: { activeChart = .seizureFrequency }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .center) {
                                        Text("Event Count")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.dashLabel)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.dashSecondary)
                                            .padding(6)
                                            .background(Circle().fill(Color.dashSecondary.opacity(0.15)))
                                    }
                                    
                                    SeizureFrequencyMiniChart(records: records, range: frequencyRange)
                                        .padding(.top, 4)
                                }
                                .padding(14)
                                .background(Color.dashCard)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.dashSeizure.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            // 2. SLEEP CARD
                            GraphCard(
                                title: "Sleep",
                                color: .dashSleep
                            ) {
                                SleepVsSeizuresMiniChart(records: records, sleep: sleep)
                            } onTap: {
                                activeChart = .sleepVsSeizures
                            }
                        }
                    }
                    
                    // ── Recent Records ───────────────────────
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

            // ── Alert Toast Overlay ───────────────────────
            if emergencyVM.status != .idle && emergencyVM.status != .countingDown {
                VStack {
                    HStack(spacing: 12) {
                        if emergencyVM.status == .sending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if emergencyVM.status == .success {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 24))
                        } else if emergencyVM.status == .failed {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 24))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(emergencyVM.status.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let errorMessage = emergencyVM.errorMessage, emergencyVM.status == .failed {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 40)
                    .onAppear {
                        if emergencyVM.status == .success || emergencyVM.status == .failed {
                            scheduleToastDismissal()
                        }
                    }
                    .onChange(of: emergencyVM.status) { _, newStatus in
                        if newStatus == .success || newStatus == .failed {
                            scheduleToastDismissal()
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(100)
            }
            
            // ── Full Screen Countdown Overlay ─────────────────────
            if emergencyVM.status == .countingDown {
                ZStack {
                    Color.black.opacity(0.95)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 40) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        VStack(spacing: 10) {
                            Text("EMERGENCY ALERT")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Sending automatically in...")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                        
                        Text("\(emergencyVM.countdownTime)")
                            .font(.system(size: 110, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                            .contentTransition(.numericText(value: Double(emergencyVM.countdownTime)))
                        
                        Spacer().frame(height: 50)
                        
                        Button(action: {
                            withAnimation {
                                emergencyVM.cancelEmergencyAlert()
                            }
                        }) {
                            ZStack {
                                Capsule()
                                    .fill(Color.red)
                                    .frame(height: 70)
                                    .frame(maxWidth: 300)
                                
                                Text("CANCEL ALERT")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()
                }
                .zIndex(200)
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $activeChart) { chart in
            switch chart {
            case .seizureFrequency:
                SeizureFrequencyChartView(records: records, initialRange: frequencyRange)
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
        .animation(.easeInOut, value: emergencyVM.status)
        .alert("Location Access Required", isPresented: $showLocationSettingsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("We need your location to send emergency alerts. Please enable it in Settings.")
        }
        .toolbar(emergencyVM.status == .countingDown ? .hidden : .visible, for: .bottomBar)
    }
    
    private func scheduleToastDismissal() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                if emergencyVM.status != .sending {
                    emergencyVM.status = .idle
                }
            }
        }
    }
}

// MARK: - Header

private struct DashboardHeaderView: View {
    @EnvironmentObject var authVM: AuthViewModel

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Summary")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dashLabel)
                Text(dateString)
                    .font(.subheadline)
                    .foregroundStyle(Color.dashSecondary)
            }
            Spacer()
            NavigationLink(destination: SettingsView(vm: authVM)) {
                Circle()
                    .fill(Color.dashCardElevated)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.dashSecondary)
                    )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Graph Card

private struct GraphCard<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let chart: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashLabel)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dashSecondary)
                        .padding(6)
                        .background(Circle().fill(Color.dashSecondary.opacity(0.15)))
                }
                
                chart
                    .frame(height: 125)
                    .clipped()
                    .padding(.top, 4)
            }
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}




