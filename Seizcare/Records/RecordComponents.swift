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
                        .font(.appSubheadline)
                        .foregroundStyle(Color.dashLabel)
                    Text("·")
                        .foregroundStyle(Color.dashTertiary)
                    Text(timeText)
                        .font(.appFootnote)
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
                            .font(.appCaption)
                            .foregroundStyle(Color.dashSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey(durationText))
                    .font(.appFootnote)
                    .foregroundStyle(Color.dashLabel)
                Text("duration")
                    .font(.appCaption)
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

// MARK: - Month Section Header

struct MonthSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title.localized.uppercased())
                .font(.appCaptionStrong)
                .foregroundStyle(Color.dashSecondary)
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
                Text("no_records_yet")
                    .font(.appTitle3)
                    .foregroundStyle(Color.dashLabel)
                Text("no_records_desc")
                    .font(.appSubheadline)
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
            Text(LocalizedStringKey(trigger.localizationKey))
                .font(.appCaptionStrong)
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
                .font(.appCallout.weight(.medium))
                .foregroundStyle(accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appCaption)
                    .foregroundStyle(Color.dashSecondary)
                Text(value)
                    .font(.appCallout.weight(.medium))
                    .foregroundStyle(Color.dashLabel)
            }
            Spacer()
        }
    }
}


// ScaleButtonStyle is defined in Auth/AuthPrimaryButton.swift — no redeclaration needed.
