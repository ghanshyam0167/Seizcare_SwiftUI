//
//  RecentRecordsView.swift
//  Seizcare
//

import SwiftUI

struct RecentRecordsView: View {
    let records: [SeizureRecord]

    private var recent: [SeizureRecord] { Array(records.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Seizures", icon: "waveform.path.ecg")

            if recent.isEmpty {
                EmptyStateCard(message: "No seizures recorded yet")
            } else {
                VStack(spacing: 8) {
                    ForEach(recent) { record in
                        RecordRow(record: record)
                    }
                }
            }
        }
    }
}

// MARK: - Record Row

private struct RecordRow: View {
    let record: SeizureRecord

    private var durationText: String {
        let m = Int(record.duration / 60)
        return m > 0 ? "\(m) min" : "<1 min"
    }

    private var dateText: String {
        let cal = Calendar.current
        if cal.isDateInToday(record.startTime)     { return "Today" }
        if cal.isDateInYesterday(record.startTime) { return "Yesterday" }
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
            // Severity indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(record.type.color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashLabel)
                    Text("·")
                        .foregroundStyle(Color.dashTertiary)
                    Text(timeText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dashSecondary)
                }
                HStack(spacing: 8) {
                    SeverityBadge(type: record.type)
                    if let trigger = record.triggers.first {
                        Text(trigger.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color.dashSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(durationText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.dashLabel)
                Text("duration")
                    .font(.caption2)
                    .foregroundStyle(Color.dashTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Severity Badge

struct SeverityBadge: View {
    let type: SeizureType

    var body: some View {
        Text(type.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(type.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(type.color.opacity(0.12))
            .clipShape(Capsule())
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
            Text(title)
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
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.dashSecondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
