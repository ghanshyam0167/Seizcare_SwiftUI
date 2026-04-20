//
//  RecordDetailView.swift
//  Seizcare
//
//  Full detail view for a single seizure record.
//  Shows summary card, triggers, notes, location, and heart rate graph.

import SwiftUI
import Charts

struct RecordDetailView: View {
    @EnvironmentObject var vm: RecordsViewModel
    @Environment(\.dismiss) private var dismiss

    let record: SeizureRecord

    @State private var showEditSheet: Bool = false
    @State private var currentRecord: SeizureRecord

    init(record: SeizureRecord) {
        self.record = record
        _currentRecord = State(initialValue: record)
    }

    // Heart rate data
    private var heartRateSamples: [HeartRateSample] {
        MockDashboardData.heartRateSamples(for: currentRecord)
    }
    
    private var effectiveEndTime: Date { currentRecord.endTime ?? Date() }

    private var durationText: String {
        let totalSecs = Int(currentRecord.duration)
        let h = totalSecs / 3600
        let m = (totalSecs % 3600) / 60
        let s = totalSecs % 60
        if h > 0 { return "\(h)h \(m)m \(s)s" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private var dateTimeText: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d · h:mm a"
        return f.string(from: currentRecord.startTime)
    }

    private var peakBPM: Int {
        heartRateSamples
            .filter { $0.timestamp >= currentRecord.startTime && $0.timestamp <= effectiveEndTime }
            .map(\.bpm)
            .max() ?? 0
    }

    private var baselineBPM: Int {
        heartRateSamples.map(\.bpm).min() ?? 0
    }

    private var recoveryBPM: Int {
        heartRateSamples.last?.bpm ?? 0
    }

    var body: some View {
        ZStack {
            Color.dashBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Summary Card ─────────────────────────
                    summaryCard

                    // ── Triggers ─────────────────────────────
                    if !currentRecord.triggers.isEmpty {
                        detailSection(icon: "bolt.fill", title: "Triggers", accentColor: .dashSeizure) {
                            FlowLayout(spacing: 8) {
                                ForEach(currentRecord.triggers) { trigger in
                                    Text(trigger.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.dashSeizure)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.dashSeizure.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // ── Notes ────────────────────────────────
                    if let notes = currentRecord.notes, !notes.isEmpty {
                        detailSection(icon: "note.text", title: "Notes", accentColor: .dashSleep) {
                            Text(notes)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dashSecondary)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // ── Location ─────────────────────────────
                    if let location = currentRecord.location, !location.isEmpty {
                        detailSection(icon: "mappin.circle.fill", title: "Location", accentColor: Color(red: 0.4, green: 0.8, blue: 0.6)) {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.6))
                                Text(location)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.dashLabel)
                            }
                        }
                    }

                    // ── Heart Rate Graph (automatic only) ────
                    if currentRecord.entryType == .automatic {
                        heartRateSection
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dashSeizure)
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            // Refresh current record if it was updated in VM
            if let updated = vm.records.first(where: { $0.id == currentRecord.id }) {
                currentRecord = updated
            } else {
                dismiss()
            }
        }) {
            AddEditRecordView(mode: .edit(currentRecord))
                .environmentObject(vm)
        }
        .onChange(of: vm.records.map(\.id)) { _, ids in
            if !ids.contains(currentRecord.id) {
                dismiss()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Top row: severity + entry type
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Circle()
                        .fill((currentRecord.type?.color ?? Color.dashTertiary))
                        .frame(width: 9, height: 9)
                    Text(LocalizedStringKey(currentRecord.type?.localizationKey ?? "unknown"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle((currentRecord.type?.color ?? Color.dashSecondary))
                }
                Spacer()
                // Entry type badge — minimal
                HStack(spacing: 4) {
                    Image(systemName: currentRecord.entryType == .automatic ? "waveform" : "pencil")
                        .font(.system(size: 10, weight: .semibold))
                    Text(currentRecord.entryType == .automatic ? "Auto-detected" : "Manual Entry")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.dashSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.dashCardElevated)
                .clipShape(Capsule())
            }

            // Main date + time
            VStack(alignment: .leading, spacing: 2) {
                Text("Seizure Event")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
                Text(dateTimeText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dashSecondary)
            }

            // Stats row — lightweight
            HStack(spacing: 0) {
                SummaryStatTile(icon: "timer", label: "Duration", value: durationText, color: .dashSecondary)
                SummaryStatDivider()
                SummaryStatTile(icon: "calendar", label: "Date", value: shortDate, color: .dashSleep)
                SummaryStatDivider()
                SummaryStatTile(icon: "clock", label: "Time", value: shortTime, color: Color(red: 0.8, green: 0.6, blue: 1.0))
            }
            .background(Color.dashCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke((currentRecord.type?.color ?? Color.dashTertiary).opacity(0.12), lineWidth: 1)
        )
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: currentRecord.startTime)
    }

    private var shortTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: currentRecord.startTime)
    }

    // MARK: - Detail Section Container

    @ViewBuilder
    private func detailSection<Content: View>(
        icon: String,
        title: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Heart Rate Section

    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dashSeizure)
                Text("Heart Rate")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dashLabel)
            }

            // Stats row
            HStack(spacing: 0) {
                HRMiniTile(label: "Baseline", value: "\(baselineBPM)", unit: "bpm", color: .dashSleep)
                HRMiniTile(label: "Peak", value: "\(peakBPM)", unit: "bpm", color: .dashSeizure)
                HRMiniTile(label: "Recovery", value: "\(recoveryBPM)", unit: "bpm", color: .dashGreen)
            }
            .background(Color.dashCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Phase legend
            HStack(spacing: 20) {
                PhaseLegendPill(label: "Before", color: .dashSleep)
                PhaseLegendPill(label: "Seizure", color: .dashSeizure)
                PhaseLegendPill(label: "After", color: .dashGreen)
                Spacer()
            }

            // Chart
            heartRateChart
                .frame(height: 200)
                .padding(.horizontal, -4)

            // Info note
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.dashTertiary)
                Text("Heart rate 60 min before, during, and after the seizure. X-axis = minutes from onset.")
                    .font(.caption2)
                    .foregroundStyle(Color.dashTertiary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.dashSeizure.opacity(0.12), lineWidth: 1)
        )
    }

    private func relativeMinutes(_ timestamp: Date) -> Double {
        timestamp.timeIntervalSince(currentRecord.startTime) / 60.0
    }

    private var chartMinBPM: Int { heartRateSamples.map(\.bpm).min().map { $0 - 10 } ?? 50 }
    private var chartMaxBPM: Int { heartRateSamples.map(\.bpm).max().map { $0 + 10 } ?? 180 }

    private var chartGradient: LinearGradient {
        let durationMins = currentRecord.duration / 60.0
        let totalMins = 60.0 + durationMins + 60.0
        let startRatio = 60.0 / totalMins
        let endRatio = (60.0 + durationMins) / totalMins
        
        return LinearGradient(
            stops: [
                .init(color: Color.dashSleep.opacity(0.85), location: 0),
                .init(color: Color.dashSleep.opacity(0.85), location: startRatio - 0.01),
                .init(color: Color.dashSeizure, location: startRatio),
                .init(color: Color.dashSeizure, location: endRatio),
                .init(color: Color.dashGreen.opacity(0.85), location: endRatio + 0.01),
                .init(color: Color.dashGreen.opacity(0.85), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private var heartRateChart: some View {
        Chart {
            // Seizure highlight band
            RectangleMark(
                xStart: .value("Start", 0.0),
                xEnd:   .value("End",   currentRecord.duration / 60.0),
                yStart: .value("Min", Double(chartMinBPM)),
                yEnd:   .value("Max", Double(chartMaxBPM))
            )
            .foregroundStyle(Color.dashSeizure.opacity(0.07))

            // HR line
            ForEach(heartRateSamples) { sample in
                let mins = relativeMinutes(sample.timestamp)

                LineMark(
                    x: .value("Minutes", mins),
                    y: .value("BPM", sample.bpm)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .foregroundStyle(chartGradient)

            // Onset marker
            RuleMark(x: .value("Onset", 0.0))
                .foregroundStyle(Color.dashSeizure.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .annotation(position: .top, alignment: .leading, spacing: 4) {
                    Text("Onset")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dashSeizure)
                }

            // End marker
            RuleMark(x: .value("End", currentRecord.duration / 60.0))
                .foregroundStyle(Color.dashGreen.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .annotation(position: .bottom, alignment: .trailing, spacing: 4) {
                    Text("End")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dashGreen)
                }
        }
        .chartXScale(domain: -65...70)
        .chartXAxis {
            AxisMarks(values: [-60, -30, 0, 15, 30, 60]) { value in
                AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v == 0 ? "0" : "\(Int(v))m")
                            .font(.caption2)
                            .foregroundStyle(Color.dashTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [60, 80, 100, 120, 140, 160]) { value in
                AxisGridLine().foregroundStyle(Color.dashTertiary.opacity(0.2))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                            .foregroundStyle(Color.dashTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Summary Stat Tile

private struct SummaryStatTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

private struct SummaryStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dashTertiary.opacity(0.2))
            .frame(width: 1, height: 40)
    }
}

// MARK: - HRMiniTile

private struct HRMiniTile: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(Color.dashSecondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dashSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Phase Legend Pill

private struct PhaseLegendPill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 4)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Flow Layout (for trigger chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecordDetailView(record: MockDashboardData.seizureRecords[0])
            .environmentObject(RecordsViewModel())
    }
    .preferredColorScheme(.dark)
}
