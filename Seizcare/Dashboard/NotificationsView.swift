import SwiftUI

// MARK: - Dummy Notification Model
struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let date: Date
    var isRead: Bool
    
    enum NotificationType {
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
}

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var recordsVM: RecordsViewModel
    
    @State private var showReportSheet: Bool = false
    
    // Dummy Data
    @State private var notifications: [AppNotification] = [
        AppNotification(
            title: "Seizure Detected",
            message: "A possible seizure was detected 5 minutes ago. Please check your logs.",
            type: .seizure,
            date: Date().addingTimeInterval(-300),
            isRead: false
        ),
        AppNotification(
            title: "Heart Rate Spike",
            message: "Your heart rate spiked to 130 BPM while resting.",
            type: .heartRate,
            date: Date().addingTimeInterval(-3600),
            isRead: false
        ),
        AppNotification(
            title: "Abnormal Activity",
            message: "Unusual movement patterns detected during your sleep.",
            type: .abnormalActivity,
            date: Date().addingTimeInterval(-86400),
            isRead: true
        ),
        AppNotification(
            title: "Weekly Report Ready",
            message: "Your seizure and health activity report for this week is ready to view.",
            type: .system,
            date: Date().addingTimeInterval(-172800),
            isRead: true
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                        .padding(12)
                        .background(Color.authCardBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Notifications")
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(notifications.indices, id: \.self) { index in
                        if notifications[index].type == .system {
                            Button {
                                notifications[index].isRead = true
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
                                notifications[index].isRead = true
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
        .background(Color.dashBg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
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
                    Text(notification.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.authPrimaryText)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.errorRed)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.message)
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
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notification Detail View
struct NotificationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let notification: AppNotification
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                        .padding(12)
                        .background(Color.authCardBackground)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Details")
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
                    Text(notification.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.authPrimaryText)
                    
                    Text(notification.date.formatted(date: .long, time: .shortened))
                        .font(.system(size: 14))
                        .foregroundColor(.authSecondaryText)
                }
                
                // Message Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.authSecondaryText)
                    
                    Text(notification.message)
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
