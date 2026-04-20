import SwiftUI
import Charts
import CoreLocation

// MARK: - Active Chart

enum ActiveChart: Identifiable, Hashable {
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
    @EnvironmentObject var languageManager: LanguageManager
    @Binding var selectedTab: Tab

    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var locationManager = LocationManager()
    @StateObject private var emergencyVM = EmergencyViewModel()
    
    @State private var sliderTriggered = false
    @State private var sliderCompleted = false
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
    private var localizedGuidanceText: String {
        localized(viewModel.guidanceText, languageCode: languageManager.currentLanguage)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.dashBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("summary")
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
                        heartRateText: viewModel.displayHeartRateText,
                        sleepHours: viewModel.avgSleep7Days
                    )
                    
                    if !viewModel.guidanceText.isEmpty && viewModel.displayHeartRate == nil {
                        Text(localizedGuidanceText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.dashSeizure)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.dashSeizure.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.bottom, 8)
                    }

                    // MARK: - Hold to Send Alert
                    HoldToAlertView(onAlertTriggered: {
                        handleEmergency()
                    }, isCompleted: $sliderCompleted)
                    .padding(.horizontal, 2)
                    .onChange(of: sliderTriggered) { _ in }

                    // Analysis Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "analysis", icon: "chart.xyaxis.line")

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
                                        Text("seizure_count")
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
                                        Text("sleep_vs_seizures")
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
            // Toast Overlay
emergencyToast

// Loading Overlay
if viewModel.isLoading {
    ZStack {
        Color.black.opacity(0.1).ignoresSafeArea()
        LoadingView()
    }
    .transition(.opacity)
    .zIndex(200)
}
         
        }
        .navigationDestination(item: $viewModel.activeChart) { chart in
            switch chart {
            case .seizureFrequency:
                SeizureFrequencyChartView(records: records, initialRange: viewModel.frequencyRange)
            case .sleepVsSeizures:
                SleepVsSeizuresChartView(records: records, sleep: sleep)
            case .heartRateTimeline(let rec):
                HeartRateTimelineChartView(record: rec)
            }
        }
        .alert("location_access_required", isPresented: $showLocationSettingsAlert) {
            Button("cancel", role: .cancel) {}
            Button("settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        } message: {
            Text("enable_location_desc")
        }
.alert("Error", isPresented: Binding(
    get: { viewModel.errorMessage != nil },
    set: { _ in
        viewModel.recordsVM.errorMessage = nil
        viewModel.healthVM.errorMessage = nil
    }
)) {
    Button("ok", role: .cancel) {}
} message: {
    Text(viewModel.errorMessage ?? "")
}

.toolbar(
    (emergencyVM.alertSuccessPopupVisible ||
     emergencyVM.alertSending)
    ? .hidden : .visible,
    for: .bottomBar
)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchTriggeredAlert"))) { _ in
            print("[Dashboard] Received Watch SOS notification for UI feedback.")
        }
    }
    
    private func localized(_ key: String, languageCode: String) -> String {
        guard !key.isEmpty,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key.localized
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    // MARK: - Emergency Logic

    private func handleEmergency() {
        if locationManager.location == nil {
            if locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted {
                showLocationSettingsAlert = true
                sliderCompleted = false
            } else {
                locationManager.requestAlwaysAuthorization()
                sliderCompleted = false
            }
        } else {
            // Slight delay so slider snap animation completes, then fire immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                emergencyVM.sendEmergencyAlertImmediately(location: locationManager.location)
            }
        }
    }

    // MARK: - Stop Alarm Overlay (centered modal)
    // Driven by alertSuccessPopupVisible
    private var emergencyToast: some View {
        Group {
            if emergencyVM.alertSuccessPopupVisible {
                ZStack {
                    // Dim background
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    // Center card — keyed by sessionID so SwiftUI always recreates it
                    VStack(spacing: 20) {

                        // Status Icon / Spinner
                        ZStack {
                            Circle()
                                .fill(
                                    emergencyVM.status == .success
                                        ? Color.green.opacity(0.12)
                                        : emergencyVM.status == .sending
                                            ? Color(red: 0.85, green: 0.10, blue: 0.10).opacity(0.08)
                                            : Color.orange.opacity(0.12)
                                )
                                .frame(width: 72, height: 72)

                            if emergencyVM.status == .sending {
                                ProgressView()
                                    .tint(Color(red: 0.85, green: 0.10, blue: 0.10))
                                    .scaleEffect(2.0)
                            } else {
                                Image(systemName:
                                    emergencyVM.status == .success
                                        ? "checkmark.shield.fill"
                                        : "exclamationmark.triangle.fill"
                                )
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(
                                    emergencyVM.status == .success ? Color.green : Color.orange
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4), value: emergencyVM.status)

                        // Status text
                        VStack(spacing: 6) {
                            Text(emergencyVM.status.rawValue.localized)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut, value: emergencyVM.status)

                            if let err = emergencyVM.errorMessage {
                                Text(err.localized)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                            } else if emergencyVM.status == .sending {
                                Text("notifying_contacts".localized)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                            } else if emergencyVM.status == .success {
                                Text("contacts_notified".localized)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Stop Alarm button — only shown after final result
                        if !emergencyVM.alertSending {
                            Button(action: {
                                print("[Alert] Stop Alarm tapped — dismissing")
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    emergencyVM.resetToIdle()
                                    sliderCompleted = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("stop_alarm".localized)
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.85, green: 0.10, blue: 0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(
                                    color: Color(red: 0.85, green: 0.10, blue: 0.10).opacity(0.3),
                                    radius: 10, x: 0, y: 4
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 10)
                    )
                    .padding(.horizontal, 36)
                    .id(emergencyVM.currentAlertSessionID)  // 🔑 Key: forces brand-new view on every alert session
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                .zIndex(100)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Glass Header Actions View
struct GlassHeaderActionsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var recordsVM: RecordsViewModel
    @EnvironmentObject var avatarVM: AvatarViewModel
    
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
            NavigationLink(destination: SettingsView(vm: authVM).environmentObject(avatarVM)) {
                if let img = avatarVM.avatarImage {
                    Image(uiImage: img)
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
        .task {
            await refreshUnreadCount()
            await avatarVM.refresh()
        }
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
