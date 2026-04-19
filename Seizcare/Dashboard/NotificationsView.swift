import SwiftUI

// MARK: - Dummy Notification Model
struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let message: String
    let type: NotificationType
    let date: Date
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case message
        case type = "notification_type"
        case date = "event_date"
        case isRead = "is_read"
    }
    
    enum NotificationType: String, Codable {
        case seizure
        case heartRate
        case abnormalActivity
        case system
        
        var icon: String {
            switch self {
            case .seizure: return "waveform.path.ecg"
            case .heartRate: return "heart.fill"
            case .abnormalActivity: return "exclamationmark.triangle.fill"
            case .system: return "bell.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .seizure: return .errorRed
            case .heartRate: return .orange
            case .abnormalActivity: return .yellow
            case .system: return .blue
            }
        }
    }
    
    var localizedTitle: String {
        switch title.lowercased() {
        case "weekly report ready": return "weekly_report_ready".localized
        case "seizure detected": return "seizure_detected".localized
        case "heart rate spike": return "heart_rate_spike".localized
        case "abnormal movement": return "abnormal_movement".localized
        default: return title.localized
        }
    }
    
    var localizedMessage: String {
        // Map dynamic backend messages to standard localized generic descriptions
        if message.lowercased().contains("seizure activity report") { return "weekly_report_ready_desc".localized }
        if message.lowercased().contains("moderate seizure was detected") { return "seizure_detected_desc".localized }
        if message.lowercased().contains("heart rate spiked") { return "heart_rate_spike_desc".localized }
        if message.lowercased().contains("unusual motion patterns") { return "abnormal_movement_desc".localized }
        return message.localized
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var recordsVM: RecordsViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var showReportSheet: Bool = false
    @State private var notifications: [AppNotification] = []
    @State private var isLoading: Bool = false
    
    // MARK: - Fetch
    
    private func fetchNotifications() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = await SupabaseService.shared.currentUserId() else {
            loadDemoNotifications(); return
        }
        do {
            let fetched = try await SupabaseService.shared.fetchNotifications(userId: userId)
            notifications = fetched.sorted { $0.date > $1.date }
        } catch {
            print("[NotificationsView] Fetch failed: \(error.localizedDescription)")
            if notifications.isEmpty { loadDemoNotifications() }
        }
    }
    
    private func loadDemoNotifications() {
        let uid = UUID()
        notifications = [
            AppNotification(id: UUID(), userId: uid, title: "weekly_report_ready",
                message: "weekly_report_ready_desc",
                type: .system, date: Date().addingTimeInterval(-3600 * 2), isRead: false),
            AppNotification(id: UUID(), userId: uid, title: "seizure_detected",
                message: "seizure_detected_desc",
                type: .seizure, date: Date().addingTimeInterval(-300), isRead: false),
            AppNotification(id: UUID(), userId: uid, title: "heart_rate_spike",
                message: "heart_rate_spike_desc",
                type: .heartRate, date: Date().addingTimeInterval(-86400), isRead: true),
            AppNotification(id: UUID(), userId: uid, title: "abnormal_movement",
                message: "abnormal_movement_desc",
                type: .abnormalActivity, date: Date().addingTimeInterval(-86400 * 2), isRead: true)
        ]
    }
    
    private func markRead(at index: Int) {
        guard !notifications[index].isRead else { return }
        notifications[index].isRead = true
        let id = notifications[index].id
        Task { try? await SupabaseService.shared.markNotificationRead(id: id) }
    }
    

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                
                Spacer()
                
                Text("notifications".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Spacer()
                
                // Invisible button to center title
                Circle()
                    .fill(Color.clear)
                    .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 20)
            
            // Notifications List
            if isLoading {
                Spacer()
            } else if notifications.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Color.dashSecondary.opacity(0.4))
                    
                    Text("no_notifications".localized)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.dashLabel)
                    
                    Text("no_notifications_desc".localized)
                        .font(.system(size: 15))
                        .foregroundColor(Color.dashSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(notifications.indices, id: \.self) { index in
                        if notifications[index].type == .system {
                            Button {
                                markRead(at: index)
                                showReportSheet = true
                            } label: {
                                NotificationRow(notification: notifications[index])
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            NavigationLink(destination: NotificationDetailView(notification: notifications[index])) {
                                NotificationRow(notification: notifications[index])
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                markRead(at: index)
                            })
                        }
                        
                        if index < notifications.count - 1 {
                            Divider()
                                .padding(.leading, 78) // Align with text
                        }
                    }
                }
                .background(Color.dashCard)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.dashSecondary.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                }
            }
            } // close VStack
            
            if isLoading {
                Color.black.opacity(0.1).ignoresSafeArea()
                LoadingView()
            }
        }
        .background(Color.dashBg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .task { await fetchNotifications() }
        .sheet(isPresented: $showReportSheet) {
            let duration = ReportDuration.week1
            let cutoff = Calendar.current.date(byAdding: .day, value: -duration.days, to: Date()) ?? Date()
            let reportRecords = recordsVM.records.filter { $0.startTime >= cutoff }
            ReportView(records: reportRecords, duration: duration)
        }
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: AppNotification
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.15))
                    .frame(width: 46, height: 46)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(notification.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.localizedTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.authPrimaryText)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.errorRed)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.localizedMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.authSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(timeAgo(from: notification.date))
                    .font(.system(size: 12))
                    .foregroundColor(.authSecondaryText.opacity(0.7))
                    .padding(.top, 2)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.authSecondaryText.opacity(0.3))
                .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(notification.isRead ? Color.clear : notification.type.color.opacity(0.05))
    }
    
    // Helper to format "5 mins ago"
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "app_language") ?? "en")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notification Detail View
struct NotificationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let notification: AppNotification
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                CustomBackButton { dismiss() }
                Spacer()
                Text("details".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                Spacer()
                Circle()
                    .fill(Color.clear)
                    .frame(width: 42, height: 42)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer().frame(height: 30)
            
            VStack(spacing: 24) {
                // Large Icon
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(notification.type.color)
                }
                
                // Title and Date
                VStack(spacing: 8) {
                    Text(notification.localizedTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                    
                    Text(notification.date.formatted(.dateTime.locale(Locale(identifier: UserDefaults.standard.string(forKey: "app_language") ?? "en")).month(.wide).day().year().hour().minute()))
                        .font(.system(size: 14))
                        .foregroundColor(.authSecondaryText)
                }
                
                // Message Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("description".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.authSecondaryText)
                    
                    Text(notification.localizedMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.authPrimaryText)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.dashCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .background(Color.dashBg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NotificationsView()
}
