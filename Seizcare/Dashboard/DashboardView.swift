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
                        Spacer()
                        
                        GlassHeaderActionsView()
                            .environmentObject(viewModel.recordsVM)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchTriggeredAlert"))) { _ in
            print("[Dashboard] Received Watch SOS notification for UI feedback.")
        }
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
                    VStack(spacing: 12) {
                        HStack {
                            Text(emergencyVM.status.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if emergencyVM.status == .sending {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        
                        if emergencyVM.status == .success || emergencyVM.status == .failed {
                            Button(action: {
                                withAnimation {
                                    emergencyVM.resetToIdle()
                                }
                            }) {
                                Text("Stop Alarm")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 24)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                    .shadow(radius: 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(emergencyVM.status == .failed ? Color.orange : Color.green)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    Spacer()
                }
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
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

// MARK: - Glass Header Actions View
struct GlassHeaderActionsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var recordsVM: RecordsViewModel
    
    @State private var hasUnread: Bool = false
    
    var body: some View {
        HStack(spacing: 24) {
            // Notifications Icon
            NavigationLink(destination:
                NotificationsView()
                    .environmentObject(recordsVM)
                    .onDisappear { Task { await refreshUnreadCount() } }
            ) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.dashLabel)
                    
                    // Unread indicator dot — only shown when there are unread notifications
                    if hasUnread {
                        Circle()
                            .fill(Color.errorRed)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                            .shadow(color: Color.errorRed.opacity(0.4), radius: 3, x: 0, y: 2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Profile Icon
            NavigationLink(destination: SettingsView(vm: authVM)) {
                if let localImage = UserDataModel.shared.getLocalAvatarImage() {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.dashLabel)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // Liquid Glass Effect
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .task { await refreshUnreadCount() }
        .animation(.spring(response: 0.3), value: hasUnread)
    }
    
    // MARK: - Helpers
    
    private func refreshUnreadCount() async {
        guard let userId = await SupabaseService.shared.currentUserId() else {
            // Fallback for demo / unauthenticated previews
            hasUnread = true
            return
        }
        do {
            let notifications = try await SupabaseService.shared.fetchNotifications(userId: userId)
            hasUnread = notifications.contains { !$0.isRead }
        } catch {
            // Keep previous state on network error
        }
    }
}