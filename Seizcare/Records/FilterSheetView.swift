//
//  FilterSheetView.swift
//  Seizcare
//

import SwiftUI

struct FilterSheetView: View {
    @Binding var filter: RecordFilter
    var onApply: () -> Void
    var onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: Severity
                    filterSection(title: "Severity", icon: "waveform.path.ecg") {
                        FlowLayout(spacing: 8) {
                            ForEach(SeizureType.allCases, id: \.self) { type in
                                FilterChip(
                                    label: type.displayName,
                                    color: type.color,
                                    isSelected: filter.severities.contains(type)
                                ) {
                                    toggle(&filter.severities, item: type)
                                }
                            }
                        }
                    }

                    // MARK: Triggers
                    filterSection(title: "Triggers", icon: "bolt.fill") {
                        FlowLayout(spacing: 8) {
                            ForEach(SeizureTrigger.allCases) { trigger in
                                FilterChip(
                                    label: trigger.rawValue,
                                    color: .dashSleep,
                                    isSelected: filter.triggers.contains(trigger)
                                ) {
                                    toggle(&filter.triggers, item: trigger)
                                }
                            }
                        }
                    }

                    // MARK: Duration
                    filterSection(title: "Duration", icon: "timer") {
                        FlowLayout(spacing: 8) {
                            ForEach(DurationBucket.allCases) { bucket in
                                FilterChip(
                                    label: bucket.rawValue,
                                    color: .dashGreen,
                                    isSelected: filter.durations.contains(bucket)
                                ) {
                                    toggle(&filter.durations, item: bucket)
                                }
                            }
                        }
                    }

                    // MARK: Date Range
                    filterSection(title: "Date Range", icon: "calendar") {
                        VStack(spacing: 8) {
                            FlowLayout(spacing: 8) {
                                ForEach([DateRangeFilter.last7, .last30]) { dr in
                                    FilterChip(
                                        label: dr.rawValue,
                                        color: Color(red: 0.8, green: 0.6, blue: 1.0),
                                        isSelected: filter.dateRange == dr
                                    ) {
                                        filter.dateRange = (filter.dateRange == dr) ? nil : dr
                                    }
                                }
                                FilterChip(
                                    label: "Custom",
                                    color: Color(red: 0.8, green: 0.6, blue: 1.0),
                                    isSelected: filter.dateRange == .custom
                                ) {
                                    filter.dateRange = (filter.dateRange == .custom) ? nil : .custom
                                }
                            }

                            if filter.dateRange == .custom {
                                VStack(spacing: 10) {
                                    DatePicker("From", selection: $filter.customStart, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.dashCardElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    DatePicker("To", selection: $filter.customEnd, in: filter.customStart..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.dashCardElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.spring(response: 0.3), value: filter.dateRange)
                            }
                        }
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.dashBg.ignoresSafeArea())
            .navigationTitle("Filter Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation { filter.reset() }
                        onReset()
                    }
                    .foregroundStyle(Color.dashSeizure)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.dashSleep)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    // MARK: Helpers

    private func toggle<T: Hashable>(_ set: inout Set<T>, item: T) {
        if set.contains(item) { set.remove(item) } else { set.insert(item) }
    }

    @ViewBuilder
    private func filterSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dashSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.dashTertiary)
                    .tracking(1.0)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.25)) { onTap() } }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color.dashSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color.dashCardElevated)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0) : Color.dashTertiary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
