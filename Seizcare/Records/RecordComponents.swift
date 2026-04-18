//
//  RecordComponents.swift
//  Seizcare
//
//  Reusable sub-components shared across the Records module.

import SwiftUI

// MARK: - Record Card (list row)

struct RecordCard: View {
    let record: SeizureRecord

    private var durationText: String {
        let totalSecs = Int(record.duration)
        let h = totalSecs / 3600
        let m = (totalSecs % 3600) / 60
        let s = totalSecs % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
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

    private var title: String {
        if let notes = record.notes, !notes.isEmpty {
            // Show a preview of the note
            let preview = String(notes.prefix(30))
            return notes.count > 30 ? "\(preview)…" : preview
        }
        return "Seizure Event"
    }

    var body: some View {
        HStack(spacing: 14) {

            // Main content
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 6) {
                    Circle()
                        .fill(record.type.color)
                        .frame(width: 7, height: 7)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashLabel)
                        .lineLimit(1)
                    
                    Image(systemName: record.entryType == .automatic ? "waveform" : "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.dashTertiary)
                        .padding(.leading, 2)
                }
                HStack(spacing: 8) {
                    SeverityBadge(type: record.type)
                    if let trigger = record.triggers.first {
                        Text(trigger.rawValue)
                            .font(.caption2)
                            .foregroundStyle(Color.dashSecondary)
                    }
                    if record.triggers.count > 1 {
                        Text("+\(record.triggers.count - 1)")
                            .font(.caption2)
                            .foregroundStyle(Color.dashTertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Date + Duration (right-aligned)
            VStack(alignment: .trailing, spacing: 4) {
                Text(dateText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dashSecondary)
                Text(timeText)
                    .font(.caption2)
                    .foregroundStyle(Color.dashTertiary)
                Text(durationText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.dashLabel)
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

// MARK: - Month Section Header

struct MonthSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.dashTertiary)
                .tracking(1.2)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

// MARK: - Records Empty State

struct RecordsEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.dashCard)
                    .frame(width: 100, height: 100)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.dashTertiary)
            }
            VStack(spacing: 8) {
                Text("No Records Yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
                Text("Tap  +  to log your first seizure event.\nYour records will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dashSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Trigger Chip

struct TriggerChip: View {
    let trigger: SeizureTrigger
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(trigger.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.dashSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? Color.dashSeizure.opacity(0.85)
                        : Color.dashCardElevated
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.dashSeizure : Color.dashTertiary.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var accentColor: Color = .dashSecondary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.dashSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.dashLabel)
            }
            Spacer()
        }
    }
}


// ScaleButtonStyle is defined in Auth/AuthPrimaryButton.swift — no redeclaration needed.
