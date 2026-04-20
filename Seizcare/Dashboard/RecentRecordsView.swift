//
//  RecentRecordsView.swift
//  Seizcare
//

import SwiftUI

struct RecentRecordsView: View {
    @EnvironmentObject var vm: RecordsViewModel
    let records: [SeizureRecord]
    var onViewAll: () -> Void = {}
    
    @State private var selectedRecord: SeizureRecord? = nil

    private var recent: [SeizureRecord] { Array(records.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "recent_seizures", icon: "waveform.path.ecg")
                Spacer()
                Button(action: {
                    onViewAll()
                }) {
                    HStack(spacing: 4) {
                        Text("view_all")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dashSeizure)
            }

            if recent.isEmpty {
                EmptyStateCard(message: "no_seizures_logged")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, record in
                        Button {
                            selectedRecord = record
                        } label: {
                            RecordRow(record: record)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        if index < recent.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color.dashCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
            }
        }
        .navigationDestination(item: $selectedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(vm)
        }
    }
}

// MARK: - Record Row

private struct RecordRow: View {
    let record: SeizureRecord

    private var durationText: String {
        let m = Int(record.duration / 60)
        return m > 0 ? "\(m) min" : "less_than_1_min"
    }

    private var dateText: String {
        let cal = Calendar.current
        if cal.isDateInToday(record.startTime)     { return "today" }
        if cal.isDateInYesterday(record.startTime) { return "yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: record.startTime)
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: record.startTime)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(LocalizedStringKey(dateText))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashLabel)
                    Text("·")
                        .foregroundStyle(Color.dashTertiary)
                    Text(timeText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashSecondary)
                        
                    Image(systemName: record.entryType == .automatic ? "waveform" : "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTertiary)
                        .padding(.leading, 2)
                }
                HStack(spacing: 8) {
                    SeverityBadge(type: record.type)
                    if let trigger = record.triggers.first {
                        Text(LocalizedStringKey(trigger.localizationKey))
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey(durationText))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.dashLabel)
                Text("duration")
                    .font(.caption2)
                    .foregroundStyle(Color.dashTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dashTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Severity Badge

struct SeverityBadge: View {
    let type: SeizureType?

    var body: some View {
        if let type {
            Text(LocalizedStringKey(type.localizationKey))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(type.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(type.color.opacity(0.12))
                .clipShape(Capsule())
        } else {
            Text("unknown")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dashSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.dashTertiary.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dashSecondary)
            Text(LocalizedStringKey(title))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.dashLabel)
        }
    }
}

struct EmptyStateCard: View {
    let message: String

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.dashTertiary)
                Text(LocalizedStringKey(message))
                    .font(.subheadline)
                    .foregroundStyle(Color.dashSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            Spacer()
        }
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
